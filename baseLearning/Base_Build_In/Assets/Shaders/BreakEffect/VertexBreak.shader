Shader "Custom/VertexBreak"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BreakAmount ("Break Amount", Range(0, 1)) = 0
        _BreakSpeed ("Break Speed", Float) = 1
        _NoiseTex ("Noise Texture", 2D) = "white" {}
    }
    
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            
            sampler2D _MainTex;
            sampler2D _NoiseTex;
            float _BreakAmount;
            float _BreakSpeed;
            
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
            
            v2f vert(a2v v)
            {
                v2f o;
                
                // 采样噪声纹理
                float noise = tex2Dlod(_NoiseTex, float4(v.uv, 0, 0)).r;
                
                // 计算破碎位移
                float3 breakOffset = v.normal * noise * _BreakAmount * _BreakSpeed;
                
                // 添加时间动画
                breakOffset += v.normal * sin(_Time.y + noise * 10) * _BreakAmount * 0.1;
                
                // 应用位移
                float3 newVertex = v.vertex.xyz + breakOffset;
                
                o.pos = UnityObjectToClipPos(float4(newVertex, 1));
                o.uv = v.uv;
                
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target
            {
                return tex2D(_MainTex, i.uv);
            }
            ENDCG
        }
    }
}