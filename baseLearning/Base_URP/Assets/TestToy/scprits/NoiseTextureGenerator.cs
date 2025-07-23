using UnityEngine;

public class NoiseTextureGenerator : MonoBehaviour
{
    [Header("噪声设置")]
    public int textureSize = 512;
    public float noiseScale = 50f;
    public int octaves = 4;
    public float persistence = 0.5f;
    public float lacunarity = 2f;
    public Vector2 offset = Vector2.zero;
    
    [Header("输出设置")]
    public string fileName = "NoiseDisplacement";
    public bool saveToAssets = true;
    
    [Header("预览")]
    public bool generateOnStart = false;
    public Material previewMaterial;
    
    void Start()
    {
        if (generateOnStart)
        {
            GenerateAndSaveNoiseTexture();
        }
    }
    
    [ContextMenu("生成噪声纹理")]
    public void GenerateAndSaveNoiseTexture()
    {
        Texture2D noiseTexture = GenerateNoiseTexture();
        
        if (saveToAssets)
        {
            SaveTextureToAssets(noiseTexture);
        }
        
        if (previewMaterial != null)
        {
            previewMaterial.mainTexture = noiseTexture;
        }
        
        Debug.Log("噪声纹理生成完成！");
    }
    
    public Texture2D GenerateNoiseTexture()
    {
        Texture2D texture = new Texture2D(textureSize, textureSize, TextureFormat.RGBA32, false);
        texture.filterMode = FilterMode.Bilinear;
        texture.wrapMode = TextureWrapMode.Repeat;
        
        float maxNoiseHeight = float.MinValue;
        float minNoiseHeight = float.MaxValue;
        
        // 生成噪声值
        for (int y = 0; y < textureSize; y++)
        {
            for (int x = 0; x < textureSize; x++)
            {
                float amplitude = 1;
                float frequency = 1;
                float noiseHeight = 0;
                
                // 多层噪声（分形噪声）
                for (int i = 0; i < octaves; i++)
                {
                    float sampleX = (x - textureSize / 2f) / noiseScale * frequency + offset.x;
                    float sampleY = (y - textureSize / 2f) / noiseScale * frequency + offset.y;
                    
                    float perlinValue = Mathf.PerlinNoise(sampleX, sampleY) * 2 - 1;
                    noiseHeight += perlinValue * amplitude;
                    
                    amplitude *= persistence;
                    frequency *= lacunarity;
                }
                
                // 记录最大最小值用于归一化
                if (noiseHeight > maxNoiseHeight)
                    maxNoiseHeight = noiseHeight;
                if (noiseHeight < minNoiseHeight)
                    minNoiseHeight = noiseHeight;
                
                // 临时存储噪声值
                texture.SetPixel(x, y, new Color(noiseHeight, noiseHeight, noiseHeight, 1));
            }
        }
        
        // 归一化噪声值到0-1范围
        for (int y = 0; y < textureSize; y++)
        {
            for (int x = 0; x < textureSize; x++)
            {
                Color pixel = texture.GetPixel(x, y);
                float normalizedValue = Mathf.InverseLerp(minNoiseHeight, maxNoiseHeight, pixel.r);
                texture.SetPixel(x, y, new Color(normalizedValue, normalizedValue, normalizedValue, 1));
            }
        }
        
        texture.Apply();
        return texture;
    }
    
    private void SaveTextureToAssets(Texture2D texture)
    {
        byte[] bytes = texture.EncodeToPNG();
        string path = "Assets/" + fileName + ".png";
        System.IO.File.WriteAllBytes(path, bytes);
        
        // 刷新Asset数据库
        UnityEditor.AssetDatabase.Refresh();
        
        // 设置纹理导入设置
        UnityEditor.TextureImporter importer = UnityEditor.AssetImporter.GetAtPath(path) as UnityEditor.TextureImporter;
        if (importer != null)
        {
            importer.textureType = UnityEditor.TextureImporterType.Default;
            importer.sRGBTexture = false; // 位移贴图通常不需要sRGB
            importer.filterMode = FilterMode.Bilinear;
            importer.wrapMode = TextureWrapMode.Repeat;
            importer.mipmapEnabled = true;
            importer.SaveAndReimport();
        }
        
        Debug.Log("噪声纹理已保存到: " + path);
    }
    
    // 生成不同类型的噪声
    [ContextMenu("生成Worley噪声")]
    public void GenerateWorleyNoise()
    {
        Texture2D texture = new Texture2D(textureSize, textureSize, TextureFormat.RGBA32, false);
        texture.filterMode = FilterMode.Bilinear;
        texture.wrapMode = TextureWrapMode.Repeat;
        
        int cellCount = 10;
        Vector2[] cellPoints = new Vector2[cellCount];
        
        // 生成随机点
        for (int i = 0; i < cellCount; i++)
        {
            cellPoints[i] = new Vector2(
                Random.Range(0f, 1f),
                Random.Range(0f, 1f)
            );
        }
        
        for (int y = 0; y < textureSize; y++)
        {
            for (int x = 0; x < textureSize; x++)
            {
                float minDistance = float.MaxValue;
                Vector2 currentPoint = new Vector2((float)x / textureSize, (float)y / textureSize);
                
                // 计算到最近点的距离
                for (int i = 0; i < cellCount; i++)
                {
                    float distance = Vector2.Distance(currentPoint, cellPoints[i]);
                    if (distance < minDistance)
                        minDistance = distance;
                }
                
                // 反转距离值（距离越近，值越大）
                float noiseValue = 1f - Mathf.Clamp01(minDistance * 3f);
                texture.SetPixel(x, y, new Color(noiseValue, noiseValue, noiseValue, 1));
            }
        }
        
        texture.Apply();
        SaveTextureToAssets(texture);
    }
    
    [ContextMenu("生成Simplex噪声")]
    public void GenerateSimplexNoise()
    {
        Texture2D texture = new Texture2D(textureSize, textureSize, TextureFormat.RGBA32, false);
        texture.filterMode = FilterMode.Bilinear;
        texture.wrapMode = TextureWrapMode.Repeat;
        
        for (int y = 0; y < textureSize; y++)
        {
            for (int x = 0; x < textureSize; x++)
            {
                float xCoord = (float)x / textureSize * noiseScale + offset.x;
                float yCoord = (float)y / textureSize * noiseScale + offset.y;
                
                float noiseValue = Mathf.PerlinNoise(xCoord, yCoord);
                texture.SetPixel(x, y, new Color(noiseValue, noiseValue, noiseValue, 1));
            }
        }
        
        texture.Apply();
        SaveTextureToAssets(texture);
    }
    
    // 生成混合噪声
    [ContextMenu("生成混合噪声")]
    public void GenerateMixedNoise()
    {
        Texture2D texture = new Texture2D(textureSize, textureSize, TextureFormat.RGBA32, false);
        texture.filterMode = FilterMode.Bilinear;
        texture.wrapMode = TextureWrapMode.Repeat;
        
        for (int y = 0; y < textureSize; y++)
        {
            for (int x = 0; x < textureSize; x++)
            {
                float xCoord = (float)x / textureSize * noiseScale + offset.x;
                float yCoord = (float)y / textureSize * noiseScale + offset.y;
                
                // 混合Perlin噪声和随机噪声
                float perlinNoise = Mathf.PerlinNoise(xCoord, yCoord);
                float randomNoise = Random.Range(0f, 1f);
                float mixedNoise = Mathf.Lerp(perlinNoise, randomNoise, 0.3f);
                
                texture.SetPixel(x, y, new Color(mixedNoise, mixedNoise, mixedNoise, 1));
            }
        }
        
        texture.Apply();
        SaveTextureToAssets(texture);
    }
} 