Shader "ShaderAni/UVAni"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Speed ("UV Speed", Vector) = (1, 1, 0, 0)  // 添加速度控制
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Speed;  // 速度参数

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 方法1：简单的UV偏移
                float2 uvOffset = _Time.y * _Speed.xy;  // 使用_Time.y获取时间
                float2 animatedUV = i.uv + uvOffset;
                
                // 方法2：循环UV偏移（推荐）
                // float2 animatedUV = frac(i.uv + _Time.y * _Speed.xy);
                
                fixed4 col = tex2D(_MainTex, animatedUV);
                return col;
            }
            ENDCG
        }
    }
}