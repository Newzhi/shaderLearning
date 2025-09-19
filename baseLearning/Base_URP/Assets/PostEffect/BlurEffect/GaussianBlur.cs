using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GaussianBlur : PostEffectsBase
{
    public Shader BlurShader;
    private Material BlurMaterial = null;
    
    public void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        
    }
}
