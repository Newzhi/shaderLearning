using UnityEngine;
using UnityEditor;

[CustomEditor(typeof(NoiseTextureGenerator))]
public class NoiseTextureGeneratorEditor : Editor
{
    public override void OnInspectorGUI()
    {
        DrawDefaultInspector();
        
        NoiseTextureGenerator generator = (NoiseTextureGenerator)target;
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("快速生成", EditorStyles.boldLabel);
        
        EditorGUILayout.BeginHorizontal();
        
        if (GUILayout.Button("生成分形噪声"))
        {
            generator.GenerateAndSaveNoiseTexture();
        }
        
        if (GUILayout.Button("生成Worley噪声"))
        {
            generator.GenerateWorleyNoise();
        }
        
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.BeginHorizontal();
        
        if (GUILayout.Button("生成Simplex噪声"))
        {
            generator.GenerateSimplexNoise();
        }
        
        if (GUILayout.Button("生成混合噪声"))
        {
            generator.GenerateMixedNoise();
        }
        
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("预设", EditorStyles.boldLabel);
        
        EditorGUILayout.BeginHorizontal();
        
        if (GUILayout.Button("地形噪声"))
        {
            generator.textureSize = 1024;
            generator.noiseScale = 100f;
            generator.octaves = 6;
            generator.persistence = 0.5f;
            generator.lacunarity = 2f;
            generator.fileName = "TerrainNoise";
            generator.GenerateAndSaveNoiseTexture();
        }
        
        if (GUILayout.Button("细节噪声"))
        {
            generator.textureSize = 512;
            generator.noiseScale = 20f;
            generator.octaves = 3;
            generator.persistence = 0.7f;
            generator.lacunarity = 2.5f;
            generator.fileName = "DetailNoise";
            generator.GenerateAndSaveNoiseTexture();
        }
        
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.BeginHorizontal();
        
        if (GUILayout.Button("粗糙噪声"))
        {
            generator.textureSize = 256;
            generator.noiseScale = 10f;
            generator.octaves = 2;
            generator.persistence = 0.3f;
            generator.lacunarity = 3f;
            generator.fileName = "RoughNoise";
            generator.GenerateAndSaveNoiseTexture();
        }
        
        if (GUILayout.Button("平滑噪声"))
        {
            generator.textureSize = 512;
            generator.noiseScale = 200f;
            generator.octaves = 4;
            generator.persistence = 0.6f;
            generator.lacunarity = 1.5f;
            generator.fileName = "SmoothNoise";
            generator.GenerateAndSaveNoiseTexture();
        }
        
        EditorGUILayout.EndHorizontal();
        
        EditorGUILayout.Space();
        EditorGUILayout.HelpBox("生成的噪声纹理将自动保存到Assets文件夹中，并设置为适合位移贴图的导入设置。", MessageType.Info);
    }
} 