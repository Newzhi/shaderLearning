// 升级提示：Unity 5.0+ 将 'mul(UNITY_MATRIX_MVP,*)' 替换为 'UnityObjectToClipPos(*)'
// 这是因为Unity 5.0引入了新的渲染管线，矩阵乘法方式发生了变化
// mul(UNITY_MATRIX_MVP, vertex) 是旧版本的写法
// UnityObjectToClipPos(vertex) 是新版本的写法，功能相同但更高效

Shader "PostEffect/basetest" {
	// Properties块：定义在Inspector中可以调节的参数
	// 这些参数可以在运行时动态修改，影响shader的渲染效果
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}  // 输入纹理，默认白色
		                                         // 这是后处理的源图像，通常是摄像机的渲染结果
		_Brightness ("Brightness", Float) = 1      // 亮度参数，默认值1（无变化）
		                                          // 范围通常在0.0-3.0之间，1.0表示原始亮度
		_Saturation("Saturation", Float) = 1      // 饱和度参数，默认值1（无变化）
		                                          // 控制颜色的鲜艳程度，0.0为黑白，1.0为原始饱和度
		_Contrast("Contrast", Float) = 1          // 对比度参数，默认值1（无变化）
		                                          // 控制明暗对比，1.0为原始对比度
	}
	
	SubShader {
		Pass {  
			// 渲染状态设置 - 这些设置对后处理效果至关重要
			ZTest Always    // 总是通过深度测试
			               // 后处理是全屏四边形，不需要与场景中的物体进行深度比较
			Cull Off        // 关闭背面剔除
			               // 确保四边形的两面都会被渲染，避免某些情况下看不到效果
			ZWrite Off      // 关闭深度写入
			               // 后处理不需要写入深度缓冲，避免影响后续的渲染操作
			
			CGPROGRAM  // 开始CG程序块
			#pragma vertex vert    // 指定顶点着色器函数名为vert
			#pragma fragment frag  // 指定片段着色器函数名为frag
			  
			#include "UnityCG.cginc"  // 包含Unity的常用函数库
			                         // 提供UnityObjectToClipPos等Unity特有函数
			  
			// 声明变量，对应Properties中的参数
			// 这些变量会在C#脚本中通过material.SetFloat等方法设置
			sampler2D _MainTex;      // 输入纹理采样器，用于读取源图像
			half _Brightness;        // 亮度值，half是16位浮点数，精度足够且性能更好
			half _Saturation;        // 饱和度值
			half _Contrast;          // 对比度值
			  
			// 顶点着色器输出结构体
			// 定义从顶点着色器传递给片段着色器的数据
			struct v2f {
				float4 pos : SV_POSITION;  // 裁剪空间位置，GPU需要这个来知道像素在屏幕上的位置
				half2 uv: TEXCOORD0;       // UV坐标，用于纹理采样，告诉GPU从纹理的哪个位置读取颜色
			};
			  
			// 顶点着色器：处理顶点数据
			// appdata_img是Unity提供的后处理专用顶点数据结构
			v2f vert(appdata_img v) {
				v2f o;  // 创建输出结构体
				
				// 将顶点从对象空间转换到裁剪空间
				// UnityObjectToClipPos是Unity 5.0+的新函数，替代了mul(UNITY_MATRIX_MVP, v.vertex)
				// 这个转换是必要的，因为GPU需要知道顶点在屏幕上的位置
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// 传递UV坐标给片段着色器
				// UV坐标用于纹理采样，告诉片段着色器从输入纹理的哪个位置读取颜色
				o.uv = v.texcoord;
						 
				return o;  // 返回处理后的顶点数据
			}
		
			// 片段着色器：处理每个像素的颜色
			// 这是后处理效果的核心，每个像素都会执行这个函数
			fixed4 frag(v2f i) : SV_Target {
				// 采样输入纹理，获取当前像素的颜色
				// tex2D是纹理采样函数，根据UV坐标从纹理中读取颜色
				// renderTex包含了原始像素的RGBA值
				fixed4 renderTex = tex2D(_MainTex, i.uv);  
				  
				// 第一步：应用亮度调整
				// 直接对RGB值进行乘法运算
				// 值>1增加亮度，值<1降低亮度
				// 例如：brightness=2.0时，所有颜色值翻倍，图像变亮
				fixed3 finalColor = renderTex.rgb * _Brightness;
				
				// 第二步：应用饱和度调整
				// 计算亮度值（使用标准RGB到灰度的转换系数）
				// 0.2125*R + 0.7154*G + 0.0721*B 是ITU-R BT.709标准的RGB到亮度转换公式
				// 这些系数反映了人眼对不同颜色的敏感度（绿色最敏感，蓝色最不敏感）
				fixed luminance = 0.2125 * renderTex.r + 0.7154 * renderTex.g + 0.0721 * renderTex.b;
				// 创建灰度版本的颜色（所有通道都是相同的亮度值）
				// 这相当于将彩色图像转换为黑白图像
				fixed3 luminanceColor = fixed3(luminance, luminance, luminance);
				// 在灰度版本和原色之间进行线性插值
				// lerp(a, b, t) = a + (b-a)*t，其中t是插值因子
				// 饱和度>1增强色彩，<1降低色彩
				// 例如：saturation=0.0时，图像变为黑白；saturation=2.0时，色彩更鲜艳
				finalColor = lerp(luminanceColor, finalColor, _Saturation);
				
				// 第三步：应用对比度调整
				// 定义中性灰色(0.5, 0.5, 0.5)作为对比度调整的基准
				// 0.5是RGB颜色空间的中点，代表中等亮度
				fixed3 avgColor = fixed3(0.5, 0.5, 0.5);
				// 在基准色和当前颜色之间进行线性插值
				// 对比度>1增强差异，<1降低差异
				// 例如：contrast=0.0时，所有像素变为中性灰色；contrast=2.0时，明暗对比更强烈
				finalColor = lerp(avgColor, finalColor, _Contrast);
				
				// 返回最终颜色，保持原始alpha值不变
				// fixed4(finalColor, renderTex.a) 将RGB和Alpha组合成完整的颜色
				// Alpha通道通常用于透明度，在后处理中保持原始值
				return fixed4(finalColor, renderTex.a);  
			}  
			  
			ENDCG  // 结束CG程序块
		}  
	}
	
	// 如果shader不支持，不提供备用方案
	// Fallback Off表示如果当前shader无法运行，不会尝试使用其他shader
	// 这确保了后处理效果的准确性，避免使用不兼容的备用shader
	Fallback Off
}