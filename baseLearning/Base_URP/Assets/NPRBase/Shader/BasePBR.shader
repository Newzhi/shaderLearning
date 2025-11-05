/*
如果你曾看过PBR的公式，那么应该已经忘了，这玩意长这样 
 ，一般人会让你从辐射度量学开始学起，从立体角到辐射率再到辐射通量......其实这个是 反射率方程的通式，他不代表任何实现和任何光照模型，其中我们只需要知道 
 即为双向反射分布函数，也就是我们需要自己实现的光照模型部分，最后这个通式其实就可以简化成 
*/
/*-       渲染结果 = 某系数 * 漫反射颜色 + （1 - 某系数） * 高光颜色   -*/
Shader "Unlit/BasePBR"
{
     Properties
    {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1.0
        _Metallic ("Metallic", Range(0, 1)) = 0.0
        _Roughness ("Roughness", Range(0, 1)) = 0.5
        _AmbientIntensity ("Ambient Intensity", Range(0, 1)) = 0.3
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            
            // PBR核心函数实现
            
            // D函数：GGX法线分布函数
            half DistributionGGX_Custom(half NdotH, half roughness)
            {
                half a = roughness * roughness;
                half a2 = a * a;
                half NdotH2 = NdotH * NdotH;
                
                half denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = PI * denom * denom;
                
                return a2 / max(denom, 0.0000001);
            }
            
            // F函数：Schlick菲涅尔近似
            half3 FresnelSchlick_Custom(half VdotH, half3 F0)
            {
                return F0 + (1.0 - F0) * pow(1.0 - VdotH, 5.0);
            }
            
            // G函数：Smith几何函数
            half GeometrySchlickGGX_Custom(half NdotV, half roughness)
            {
                half r = (roughness + 1.0);
                half k = (r * r) / 8.0;
                
                half denom = NdotV * (1.0 - k) + k;
                return NdotV / max(denom, 0.0000001);
            }
            
            half GeometrySmith_Custom(half NdotV, half NdotL, half roughness)
            {
                half ggx2 = GeometrySchlickGGX_Custom(NdotV, roughness);
                half ggx1 = GeometrySchlickGGX_Custom(NdotL, roughness);
                return ggx1 * ggx2;
            }
            
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _MainTex_ST;
                float4 _BumpMap_ST;
                float _BumpScale;
                float _Metallic;
                float _Roughness;
                float _AmbientIntensity;
            CBUFFER_END
            
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            
            // 输入结构体
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };
            
            // 输出结构体
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 tangentWS : TEXCOORD2;
                float3 bitangentWS : TEXCOORD3;
                float3 positionWS : TEXCOORD4;
                float3 viewDirWS : TEXCOORD5;
            };
            
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // 顶点变换
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                // UV坐标
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                // 法线和切线变换到世界空间
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                output.bitangentWS = cross(output.normalWS, output.tangentWS) * input.tangentOS.w;
                
                // 计算视图方向
                output.viewDirWS = GetCameraPositionWS() - output.positionWS;
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                // 获取主纹理颜色
                half4 albedoTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                half3 albedo = albedoTex.rgb * _Color.rgb;
                
                // 获取法线贴图
                half4 packedNormal = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);
                half3 normalTS = UnpackNormal(packedNormal);
                normalTS.xy *= _BumpScale;
                normalTS.z = sqrt(1.0 - saturate(dot(normalTS.xy, normalTS.xy)));
                
                // 构建切线空间到世界空间的变换矩阵
                float3x3 tangentToWorld = CreateTangentToWorld(input.normalWS, input.tangentWS, input.bitangentWS);
                
                // 法线从切线空间转换到世界空间
                half3 normalWS = TransformTangentToWorld(normalTS, tangentToWorld);
                normalWS = NormalizeNormalPerPixel(normalWS);
                
                // PBR参数
                half metallic = _Metallic;
                half roughness = _Roughness;
                
                // 获取光照信息
                Light mainLight = GetMainLight();
                half3 lightDirWS = normalize(mainLight.direction);
                half3 viewDirWS = normalize(input.viewDirWS);
                half3 halfDirWS = normalize(lightDirWS + viewDirWS);
                
                // 计算基础值
                half NdotL = saturate(dot(normalWS, lightDirWS));
                half NdotV = saturate(dot(normalWS, viewDirWS));
                half NdotH = saturate(dot(normalWS, halfDirWS));
                half VdotH = saturate(dot(viewDirWS, halfDirWS));
                
                // 计算F0（基础反射率）
                half3 F0 = lerp(half3(0.04, 0.04, 0.04), albedo, metallic);
                
                // 计算DFG
                half D = DistributionGGX_Custom(NdotH, roughness);
                half3 F = FresnelSchlick_Custom(VdotH, F0);
                half G = GeometrySmith_Custom(NdotV, NdotL, roughness);
                
                // Cook-Torrance BRDF
                half3 numerator = D * F * G;
                half denominator = 4.0 * NdotV * NdotL + 0.0001;
                half3 specular = numerator / denominator;
                
                // 能量守恒：计算kd和ks
                half3 kd = (1.0 - F) * (1.0 - metallic); // 金属不产生漫反射
                half3 ks = F;
                
                // 漫反射（Lambert）
                half3 diffuse = kd * albedo / PI;
                
                // 高光反射（Cook-Torrance）
                half3 spec = ks * specular;
                
                // 直接光照
                half3 directLighting = (diffuse + spec) * mainLight.color * NdotL;
                
                // 环境光
                half3 ambient = SampleSH(half4(normalWS, 1.0)) * albedo * _AmbientIntensity;
                
                // 最终颜色
                half3 finalColor = directLighting + ambient;
                
                return half4(finalColor, albedoTex.a);
            }
            ENDHLSL
        }
    }
    
    FallBack "Universal Render Pipeline/Lit"
}
