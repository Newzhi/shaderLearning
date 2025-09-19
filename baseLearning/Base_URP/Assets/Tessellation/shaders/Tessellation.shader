Shader "Custom/URPTessellationShader"
{
    Properties
    {
        _Color ("主颜色", Color) = (1,1,1,1)
        _TessellationFactor ("细分因子", Range(1, 32)) = 4
        _DisplacementMap ("位移贴图", 2D) = "black" {}
        _DisplacementStrength ("位移强度", Range(0, 1)) = 0.1
        _DisplacementScale ("位移缩放", Range(0.1, 10)) = 1
        _MainTex ("主纹理", 2D) = "white" {}
        _NormalMap ("法线贴图", 2D) = "bump" {}
        _Smoothness ("光滑度", Range(0, 1)) = 0.5
        _Metallic ("金属度", Range(0, 1)) = 0
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        LOD 300
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma hull hull
            #pragma domain domain
            
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            struct TessellationFactors
            {
                float edge[3] : SV_TessFactor;
                float inside : SV_InsideTessFactor;
            };
            
            struct TessellationControlPoint
            {
                float4 positionOS : INTERNALTESSPOS;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            struct Interpolators
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float4 shadowCoord : TEXCOORD4;
            };
            
            TEXTURE2D(_MainTex);
            TEXTURE2D(_NormalMap);
            TEXTURE2D(_DisplacementMap);
            SAMPLER(sampler_MainTex);
            SAMPLER(sampler_NormalMap);
            SAMPLER(sampler_DisplacementMap);
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _NormalMap_ST;
                float4 _DisplacementMap_ST;
                half4 _Color;
                float _TessellationFactor;
                float _DisplacementStrength;
                float _DisplacementScale;
                half _Smoothness;
                half _Metallic;
            CBUFFER_END
            
            // 顶点着色器 - 准备细分控制点数据
            TessellationControlPoint vert(Attributes input)
            {
                TessellationControlPoint output;
                output.positionOS = input.positionOS;
                output.normalOS = input.normalOS;
                output.tangentOS = input.tangentOS;
                output.uv = input.uv;
                return output;
            }
            
            // 细分控制着色器常量函数
            TessellationFactors hullConstant(InputPatch<TessellationControlPoint, 3> patch)
            {
                TessellationFactors output;
                output.edge[0] = _TessellationFactor;
                output.edge[1] = _TessellationFactor;
                output.edge[2] = _TessellationFactor;
                output.inside = _TessellationFactor;
                return output;
            }
            
            // 细分控制着色器
            [domain("tri")]
            [partitioning("fractional_odd")]
            [outputtopology("triangle_cw")]
            [outputcontrolpoints(3)]
            [patchconstantfunc("hullConstant")]
            TessellationControlPoint hull(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
            {
                return patch[id];
            }
            
            // 细分评估着色器
            [domain("tri")]
            Interpolators domain(TessellationFactors factors, OutputPatch<TessellationControlPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
            {
                Interpolators output;
                
                // 插值顶点属性
                float4 positionOS = patch[0].positionOS * barycentricCoordinates.x + 
                                   patch[1].positionOS * barycentricCoordinates.y + 
                                   patch[2].positionOS * barycentricCoordinates.z;
                
                float3 normalOS = patch[0].normalOS * barycentricCoordinates.x + 
                                 patch[1].normalOS * barycentricCoordinates.y + 
                                 patch[2].normalOS * barycentricCoordinates.z;
                
                float4 tangentOS = patch[0].tangentOS * barycentricCoordinates.x + 
                                  patch[1].tangentOS * barycentricCoordinates.y + 
                                  patch[2].tangentOS * barycentricCoordinates.z;
                
                float2 uv = patch[0].uv * barycentricCoordinates.x + 
                           patch[1].uv * barycentricCoordinates.y + 
                           patch[2].uv * barycentricCoordinates.z;
                
                // 在细分评估着色器中应用位移贴图
                float displacement = SAMPLE_TEXTURE2D_LOD(_DisplacementMap, sampler_DisplacementMap, uv * _DisplacementMap_ST.xy + _DisplacementMap_ST.zw, 0).r;
                
                // 基于细分因子调整位移强度，让位移效果随细分精度变化
                float adaptiveDisplacementStrength = _DisplacementStrength * _DisplacementScale * (1.0 + _TessellationFactor * 0.1);
                positionOS.xyz += normalOS * displacement * adaptiveDisplacementStrength;
                
                // 转换到世界空间
                output.positionWS = TransformObjectToWorld(positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(normalOS);
                output.tangentWS = float4(TransformObjectToWorldDir(tangentOS.xyz), tangentOS.w);
                output.uv = uv * _MainTex_ST.xy + _MainTex_ST.zw;
                
                // 转换到裁剪空间
                output.positionCS = TransformWorldToHClip(output.positionWS);
                
                // 计算阴影坐标
                output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
                
                return output;
            }
            
            // 片段着色器
            half4 frag(Interpolators input) : SV_Target
            {
                // 采样纹理
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv) * _Color;
                
                // 采样法线贴图
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));
                
                // 构建TBN矩阵
                float3x3 tangentToWorld = CreateTangentToWorld(input.normalWS, input.tangentWS.xyz, input.tangentWS.w);
                half3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
                normalWS = NormalizeNormalPerPixel(normalWS);
                
                // 光照计算
                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                inputData.shadowCoord = input.shadowCoord;
                
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = albedo.rgb;
                surfaceData.metallic = _Metallic;
                surfaceData.specular = half3(0, 0, 0);
                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS = normalTS;
                surfaceData.occlusion = 1;
                surfaceData.emission = 0;
                surfaceData.alpha = albedo.a;
                
                return UniversalFragmentPBR(inputData, surfaceData);
            }
            ENDHLSL
        }
        
        // 阴影投射Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull[_Cull]
            
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            
            ENDHLSL
        }
        
        // 深度写入Pass
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }
            
            ZWrite On
            ColorMask 0
            Cull[_Cull]
            
            HLSLPROGRAM
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
} 