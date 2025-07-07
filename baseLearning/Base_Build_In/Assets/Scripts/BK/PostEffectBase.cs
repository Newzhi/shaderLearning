using UnityEngine;
using System.Collections;

// 在编辑模式下也执行此脚本，方便在Scene视图中预览效果
[ExecuteInEditMode]
// 要求GameObject必须附加Camera组件
[RequireComponent (typeof(Camera))]
public class PostEffectsBase : MonoBehaviour {

    // 在开始时调用，检查平台是否支持后处理效果
    protected void CheckResources() {
        // 检查当前平台是否支持图像效果
        bool isSupported = CheckSupport();
		
        // 如果不支持，则禁用该效果
        if (isSupported == false) {
            NotSupported();
        }
    }

    // 在CheckResources中调用，检查当前平台对后处理效果的支持情况
    protected bool CheckSupport() {
        // 检查平台是否支持图像效果和渲染纹理
        // SystemInfo.supportsImageEffects：是否支持图像效果
        // SystemInfo.supportsRenderTextures：是否支持渲染纹理
        if (SystemInfo.supportsImageEffects == false || SystemInfo.supportsRenderTextures == false) {
            Debug.LogWarning("This platform does not support image effects or render textures.");
            return false;
        }
		
        return true;
    }

    // 当平台不支持此效果时调用
    protected void NotSupported() {
        // 禁用该MonoBehaviour组件，停止后处理效果
        enabled = false;
    }
	
    // Unity生命周期方法，在Start时检查资源支持情况
    protected void Start() {
        CheckResources();
    }

    // 当需要创建此效果使用的材质时调用
    // 参数：shader - 要使用的着色器，material - 现有的材质（可能为null）
    protected Material CheckShaderAndCreateMaterial(Shader shader, Material material) {
        // 如果着色器为空，返回null
        if (shader == null) {
            return null;
        }
		
        // 如果着色器受支持，且材质存在且材质使用的着色器正确，直接返回现有材质
        // 这避免了重复创建材质，提高性能
        if (shader.isSupported && material && material.shader == shader)
            return material;
		
        // 如果着色器不受支持，返回null
        if (!shader.isSupported) {
            return null;
        }
        else {
            // 创建新的材质并应用着色器
            material = new Material(shader);
            // 设置材质标志为不保存，避免在场景中保存材质资源
            material.hideFlags = HideFlags.DontSave;
            // 如果材质创建成功，返回材质；否则返回null
            if (material)
                return material;
            else 
                return null;
        }
    }
}