Shader "Mylit/BasePhong"
{
    Properties
    {         
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1, 1, 1, 1)
        _SpecularColor ("Specular Color", Color) = (1, 1, 1, 1)
        _Shininess ("Shininess", Range(1, 128)) = 32
        _AmbientIntensity ("Ambient Intensity", Range(0, 1)) = 0.3
    }

    SubShader
    {
        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"           
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;
                float4 _SpecularColor;
                float _Shininess;
                float _AmbientIntensity;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float4 texcoord : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                float3 normalWS : TEXCOORD3;
                float3 lightDirWS : TEXCOORD4;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS.xyz);
                
                // 计算视图方向（从顶点到相机）
                OUT.viewDirWS = GetCameraPositionWS() - OUT.positionWS;
                
                // 获取主光源方向
                Light mainLight = GetMainLight();
                OUT.lightDirWS = mainLight.direction;
                
                // 使用Unity自带的UV变换函数
                OUT.uv = TRANSFORM_TEX(IN.texcoord, _MainTex);
                
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 归一化向量
                float3 normalWS = normalize(IN.normalWS);
                float3 viewDirWS = normalize(IN.viewDirWS);
                float3 lightDirWS = normalize(IN.lightDirWS);
                
                // 获取主光源
                Light light = GetMainLight(TransformWorldToShadowCoord(IN.positionWS));
                
                // 1. 环境光 (Ambient)
                half3 ambient = SampleSH(half4(normalWS, 1.0)) * _AmbientIntensity;
                
                // 2. 漫反射 (Diffuse) - Lambert光照模型
                half NdotL = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = light.color * NdotL;
                
                // 3. 高光反射 (Specular) - Phong高光模型
                // 计算反射向量
                float3 reflectDir = reflect(-lightDirWS, normalWS);
                // 计算高光强度
                half RdotV = saturate(dot(reflectDir, viewDirWS));
                half3 specular = light.color * _SpecularColor.rgb * pow(RdotV, _Shininess);
                
                // 采样纹理
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                
                // 组合最终颜色：环境光 + 漫反射 + 高光
                half3 finalColor = (ambient + diffuse + specular) * albedo.rgb * _Color.rgb;
                
                return half4(finalColor, albedo.a);
            }
            ENDHLSL
        }
    }
}