Shader "NBRtest/URPBasicTemplate"
{
        Properties
    {
        _MainTex ("主纹理", 2D) = "white" {}
        _NormalMap ("法线贴图", 2D) = "bump" {}
        _EmissionTex ("发光贴图", 2D) = "black" {}
        _MetallicTex ("金属度贴图", 2D) = "white" {}
    }

    SubShader
    {
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 声明所有纹理
            TEXTURE2D(_MainTex);
            TEXTURE2D(_NormalMap);
            TEXTURE2D(_EmissionTex);
            TEXTURE2D(_MetallicTex);

            // 声明所有采样器
            SAMPLER(sampler_MainTex);
            SAMPLER(sampler_NormalMap);
            SAMPLER(sampler_EmissionTex);
            SAMPLER(sampler_MetallicTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 采样所有纹理
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half3 normal = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv));
                half4 emission = SAMPLE_TEXTURE2D(_EmissionTex, sampler_EmissionTex, IN.uv);
                half metallic = SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, IN.uv).r;

                // 组合最终颜色
                half4 finalColor = albedo + emission;
                return finalColor;
            }
            ENDHLSL
        }
    }
}