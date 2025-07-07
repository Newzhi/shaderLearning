Shader "ShaderAni/BillBoard"
{
   Properties {
		_MainTex ("主纹理", 2D) = "white" {}
		_Color ("颜色调整", Color) = (1, 1, 1, 1)
		_VerticalBillboarding ("垂直约束", Range(0, 1)) = 1 
	}
	SubShader {
		// 需要禁用批处理，因为顶点动画会改变顶点位置
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "DisableBatching"="True"}
		
		Pass { 
			Tags { "LightMode"="ForwardBase" }
			
			ZWrite Off  // 关闭深度写入，用于透明效果
			Blend SrcAlpha OneMinusSrcAlpha  // 标准透明混合
			//Cull Off  // 可选：关闭背面剔除
		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			fixed4 _Color;
			fixed _VerticalBillboarding;
			
			// 顶点着色器输入结构
			struct a2v {
				float4 vertex : POSITION;    // 顶点位置
				float4 texcoord : TEXCOORD0; // UV坐标
			};
			
			// 顶点着色器输出结构
			struct v2f {
				float4 pos : SV_POSITION;    // 裁剪空间位置
				float2 uv : TEXCOORD0;       // UV坐标
			};
			
			v2f vert (a2v v) {
				v2f o;
				
				// 假设物体空间中的中心点固定在原点
				float3 center = float3(0, 0, 0);
				
				// 将世界空间相机位置转换到物体空间
				// 这样可以得到从物体中心到相机的方向向量
				float3 viewer = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
				
				// 计算从中心到相机的方向向量，这就是我们想要的朝向
				float3 normalDir = viewer - center;
				
				// 垂直约束处理：
				// 如果 _VerticalBillboarding = 1，使用完整的朝向向量（完全面向相机）
				// 如果 _VerticalBillboarding = 0，Y分量为0（只在水平面旋转，保持垂直）
				// 中间值提供部分约束
				normalDir.y = normalDir.y * _VerticalBillboarding;
				normalDir = normalize(normalDir);
				
				// 计算近似的上方向向量
				// 如果法线方向已经接近垂直向上，则上方向指向前方
				// 否则上方向指向世界空间的Y轴正方向
				float3 upDir = abs(normalDir.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
				
				// 计算右方向向量（上方向与法线方向的叉积）
				float3 rightDir = normalize(cross(upDir, normalDir));
				
				// 重新计算上方向向量，确保三个向量正交
				upDir = normalize(cross(normalDir, rightDir));
				
				// 使用这三个正交向量构建旋转矩阵
				// 将原始顶点相对于中心点的偏移量应用旋转
				float3 centerOffs = v.vertex.xyz - center;
				float3 localPos = center + rightDir * centerOffs.x + upDir * centerOffs.y + normalDir * centerOffs.z;
              
				// 转换到裁剪空间
				o.pos = UnityObjectToClipPos(float4(localPos, 1));
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

				return o;
			}
			
			// 片段着色器
			fixed4 frag (v2f i) : SV_Target {
				// 采样纹理
				fixed4 c = tex2D (_MainTex, i.uv);
				// 应用颜色调整
				c.rgb *= _Color.rgb;
				
				return c;
			}
			
			ENDCG
        }
    }
} 