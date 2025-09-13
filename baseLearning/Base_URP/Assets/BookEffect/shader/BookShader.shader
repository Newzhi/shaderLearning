Shader "Custom/URPBasicTemplate"
{
    Properties
    {
        //正面与背面贴图
        _FrontTex ("FrontTex", 2D) = "white" {}
        _BackTex("NextTex",2D) = "white"{}
        
        //翻页效果设置属性
        _RotateAngle("RotateAngle",Range(0,180)) = 5 //翻页角度
        _RotateOffset("RotateOffset",Vector) = (5,0,0,0) //旋转偏移量
        _Wave("wave",Float) = 0.5
    }

    SubShader
    {
        Tags {"Queue" = "Transparent" "RenderPipeline" = "UniversalPipeline"}
       
        Pass
        {
            Tags {"LightMode" = "UniversalForward"}
            Cull Off
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"           
            
            CBUFFER_START(UnityPerMaterial)
                float4 _FrontTex_ST;
                float4 _BackTex_ST;
                float _RotateAngle;
                float _Wave;
                float4 _RotateOffset;
            CBUFFER_END

            TEXTURE2D(_FrontTex);SAMPLER(sampler_FrontTex);
            TEXTURE2D(_BackTex);SAMPLER(sampler_BackTex);            

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                float cosx;
                float sinx;
                sincos(radians(_RotateAngle),sinx,cosx);
                float4x4 RotateMatria = {
                    cosx,sinx,0,0,
                    -sinx,cosx,0,0,
                    0,0,1,0,
                    0,0,0,1,
                };
                IN.positionOS -= _RotateOffset;
                IN.positionOS.y = sin(IN.positionOS.x * _Wave) * sinx;
                IN.positionOS = mul(RotateMatria,IN.positionOS);
                IN.positionOS += _RotateOffset;
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv.xy = IN.uv;
                OUT.uv.zw = float2(1 - IN.uv.x, IN.uv.y);
                return OUT;
            }

            half4 frag(Varyings IN , bool isFrontFace : SV_IsFrontFace) : SV_Target
            {

                half4 FrontTex = SAMPLE_TEXTURE2D(_FrontTex, sampler_FrontTex, IN.uv.xy);
                half4 BackTex = SAMPLE_TEXTURE2D(_BackTex, sampler_BackTex, IN.uv.zw);
                float4 res = IS_FRONT_VFACE(isFrontFace,FrontTex,BackTex);
                return res;
            }
            ENDHLSL
        }
    }
}
