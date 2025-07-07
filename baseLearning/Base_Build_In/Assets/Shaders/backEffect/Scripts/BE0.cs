using UnityEngine;
using System.Collections;

// 亮度、饱和度和对比度后处理效果类
// 继承自PostEffectsBase基类，获得平台兼容性检查和材质管理功能
public class BrightnessSaturationAndContrast : PostEffectsBase {

    // 公开的Shader引用，在Inspector中可以指定对应的shader文件
    public Shader briSatConShader;
    
    // 私有的材质变量，用于缓存创建的材质
    private Material briSatConMaterial;
    
    // 公开的材质属性，提供对材质的访问
    // 使用属性访问器，确保每次访问时都检查并创建材质
    public Material material {  
        get {
            // 调用基类方法检查shader并创建材质
            // 如果材质已存在且shader正确，直接返回；否则创建新材质
            briSatConMaterial = CheckShaderAndCreateMaterial(briSatConShader, briSatConMaterial);
            return briSatConMaterial;
        }  
    }

    // 亮度参数，使用Range特性限制在0.0f到3.0f之间
    // 在Inspector中显示为滑动条，默认值1.0f表示无变化
    [Range(0.0f, 3.0f)]
    public float brightness = 1.0f;

    // 饱和度参数，使用Range特性限制在0.0f到3.0f之间
    // 在Inspector中显示为滑动条，默认值1.0f表示无变化
    [Range(0.0f, 3.0f)]
    public float saturation = 1.0f;

    // 对比度参数，使用Range特性限制在0.0f到3.0f之间
    // 在Inspector中显示为滑动条，默认值1.0f表示无变化
    [Range(0.0f, 3.0f)]
    public float contrast = 1.0f;

    // Unity后处理的标准接口方法
    // 在渲染管线中被调用，用于处理渲染纹理
    // src: 源纹理（通常是摄像机的渲染结果）
    // dest: 目标纹理（处理后的结果）
    void OnRenderImage(RenderTexture src, RenderTexture dest) {
        // 检查材质是否成功创建
        if (material != null) {
            // 将C#中的参数值传递给shader中的对应变量
            // 这些变量名必须与shader中的Properties名称完全匹配
            material.SetFloat("_Brightness", brightness);  // 设置亮度值
            material.SetFloat("_Saturation", saturation);  // 设置饱和度值
            material.SetFloat("_Contrast", contrast);      // 设置对比度值

            // 使用Graphics.Blit进行全屏后处理渲染
            // 将源纹理通过指定材质渲染到目标纹理
            // 这会调用shader的顶点和片段着色器对每个像素进行处理
            Graphics.Blit(src, dest, material);
        } else {
            // 如果材质创建失败（例如shader不支持），直接复制源纹理到目标纹理
            // 这确保了即使后处理失败，游戏仍能正常运行
            Graphics.Blit(src, dest);
        }
    }
}