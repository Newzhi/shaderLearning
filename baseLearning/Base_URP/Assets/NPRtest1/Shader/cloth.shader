Shader "URP/RampTex"
{
    Properties
    {
        _MainTex ("主纹理", 2D) = "white" {}
        _Color ("颜色着色", Color) = (1, 1, 1, 1)
        _RampTex ("渐变纹理", 2D) = "white" {}
        
        // 描边效果
        _OutlineWidth ("描边宽度", Range(0.0, 3.0)) = 1.0
        _OutlineColor ("描边颜色", Color) = (1.0, 1.0, 1.0, 1.0)
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

            // 多光源支持
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            // URP核心库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            // 属性声明
            CBUFFER_START(UnityPerMaterial)
                float4 _Color;
                float4 _MainTex_ST;
                float4 _RampTex_ST;
                float _OutlineWidth;
                float4 _OutlineColor;
            CBUFFER_END

            // 纹理和采样器声明
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            // 输入结构体
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            // 输出结构体
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            // 顶点着色器
            Varyings vert(Attributes input)
            {
                Varyings output;
                
                // 顶点位置变换
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                
                // 法线变换到世界空间
                output.worldNormal = TransformObjectToWorldNormal(input.normalOS);
                
                // 顶点位置变换到世界空间
                output.worldPos = TransformObjectToWorld(input.positionOS.xyz);
                
                // UV坐标处理
                output.uv.xy = input.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                output.uv.zw = input.uv * _RampTex_ST.xy + _RampTex_ST.zw;
                
                return output;
            }

            // 片段着色器
            half4 frag(Varyings input) : SV_Target
            {
                // 归一化世界空间法线
                float3 worldNormal = normalize(input.worldNormal);
                
                // 获取主光源
                Light mainLight = GetMainLight();
                float3 worldLightDir = normalize(mainLight.direction);
                
                // 环境光
                //half3 ambient = SampleSH(half4(worldNormal, 1.0));
                half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                
                // 主光源半兰伯特光照计算
                half halfLambert = 0.5 * dot(worldNormal, worldLightDir) + 0.5;
                
                // 使用渐变纹理控制漫反射颜色
                half3 diffuseColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, 
                    half2(halfLambert, halfLambert)).rgb * _Color.rgb;
                
                // 主光源漫反射光照
                half3 diffuse = mainLight.color * diffuseColor * mainLight.distanceAttenuation;
                
                // 额外光源处理
                #ifdef _ADDITIONAL_LIGHTS
                uint pixelLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0; lightIndex < pixelLightCount; ++lightIndex)
                {
                    Light light = GetAdditionalLight(lightIndex, input.worldPos);
                    
                    // 额外光源的半兰伯特计算
                    float3 additionalLightDir = normalize(light.direction);
                    half additionalHalfLambert = 0.5 * dot(worldNormal, additionalLightDir) + 0.5;
                    
                    // 额外光源的渐变纹理采样
                    half3 additionalDiffuseColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, 
                        half2(additionalHalfLambert, additionalHalfLambert)).rgb * _Color.rgb;
                    
                    // 额外光源漫反射光照
                    half3 additionalDiffuse = light.color * additionalDiffuseColor * light.distanceAttenuation;
                    diffuse += additionalDiffuse;
                }
                #endif
                
                // 采样主纹理
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv.xy);
                
                // 组合最终颜色
                return half4((ambient + diffuse) * mainTex.rgb, 1.0);
            }
            ENDHLSL
        }

        // 描边Pass
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            
            Cull Front
            ZWrite On
            ZTest LEqual
            
            //ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 描边属性
            CBUFFER_START(UnityPerMaterial)
                float _OutlineWidth;
                float4 _OutlineColor;
            CBUFFER_END

            // 描边输入结构体
            struct OutlineAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            // 描边输出结构体
            struct OutlineVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            // 描边顶点着色器
            OutlineVaryings vert(OutlineAttributes input)
            {
                OutlineVaryings output;
                
                // 法线外扩方案 - 使用URP的变换函数
                float3 worldPos = TransformObjectToWorld(input.positionOS.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(input.normalOS);
                
                // 转换到视图空间
                float3 viewPos = TransformWorldToView(worldPos);
                float3 viewNormal = TransformWorldToViewDir(worldNormal, false);
                
                // 将法线的z分量设为负值，确保外扩方向正确
                viewNormal.z = -0.5;
                
                // 沿法线方向外扩顶点
                viewPos = viewPos + normalize(viewNormal) * _OutlineWidth * 0.002;
                
                // 转换到裁剪空间 - 使用正确的URP函数
                output.positionCS = TransformWViewToHClip(viewPos);
                
                return output;
            }

            // 描边片段着色器
            half4 frag(OutlineVaryings input) : SV_Target
            {
                return _OutlineColor;
            }
            ENDHLSL
        }
    }
    
    Fallback "Universal Render Pipeline/Lit"
}