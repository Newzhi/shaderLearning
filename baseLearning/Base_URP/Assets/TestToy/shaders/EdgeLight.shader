Shader "Custom/URPStencilOutline"
{
    Properties
    {         
        _MainTex ("主纹理", 2D) = "white" {}
        _OutlineWidth ("描边宽度", Range(0, 10)) = 1
        [HDR]_OutlineColor ("描边颜色", Color) = (0, 0, 0, 1)
        _OutlineThreshold ("描边阈值", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags 
        { 
            "Queue" = "Transparent" 
            "IgnoreProjector" = "True" 
            "RenderType" = "Transparent" 
            "PreviewType" = "Plane" 
            "CanUseSpriteAtlas" = "True" 
            "RenderPipeline" = "UniversalPipeline"
        }
        
        ZWrite Off 
        Blend SrcAlpha OneMinusSrcAlpha 
        Cull Off

        // Pass 1: 写入模板缓冲区
        Pass
        {
            Name "StencilWrite"
            Tags { "LightMode" = "UniversalForward" }
            
            // 模板测试设置
            Stencil
            {
                Ref 1
                Comp Always
                Pass Replace
                Fail Keep
                ZFail Keep
            }
            
            // 只写入模板，不输出颜色
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

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
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 只检查alpha值，不输出颜色
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                clip(texColor.a - 0.5); // 如果alpha小于0.5，丢弃像素
                return float4(0, 0, 0, 0); // 不输出颜色
            }
            ENDHLSL
        }

        // Pass 2: 绘制描边
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "UniversalForward" }
            
            // 模板测试：只在模板值不等于1的地方绘制
            Stencil
            {
                Ref 1
                Comp NotEqual
                Pass Keep
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _OutlineWidth;
                float4 _OutlineColor;
                float _OutlineThreshold;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.color = IN.color;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 在描边区域绘制描边颜色
                return _OutlineColor * IN.color;
            }
            ENDHLSL
        }

        // Pass 3: 绘制原始内容
        Pass
        {
            Name "MainContent"
            Tags { "LightMode" = "UniversalForward" }
            
            // 模板测试：只在模板值等于1的地方绘制
            Stencil
            {
                Ref 1
                Comp Equal
                Pass Keep
                Fail Keep
                ZFail Keep
            }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
            CBUFFER_END

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.color = IN.color;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // 绘制原始纹理内容
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                return texColor * IN.color;
            }
            ENDHLSL
        }
    }
    Fallback "Sprites/Default"
} 