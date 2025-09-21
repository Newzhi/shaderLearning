using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

public class LoadSceneMgr : MonoBehaviour
{
    [Header("场景跳转设置")]
    public Button loadSceneButton;
    public string targetSceneName = "SampleScene";
    
    void Start()
    {
        // 如果没有手动分配按钮，尝试自动查找
        if (loadSceneButton == null)
        {
            loadSceneButton = GetComponent<Button>();
        }
        
        // 绑定按钮点击事件
        if (loadSceneButton != null)
        {
            loadSceneButton.onClick.AddListener(LoadTargetScene);
        }
        else
        {
            Debug.LogError("LoadSceneMgr: 没有找到按钮组件！");
        }
    }
    
    /// <summary>
    /// 加载目标场景
    /// </summary>
    public void LoadTargetScene()
    {
        if (string.IsNullOrEmpty(targetSceneName))
        {
            Debug.LogError("LoadSceneMgr: 目标场景名称为空！");
            return;
        }
        
        Debug.Log($"正在加载场景: {targetSceneName}");
        SceneManager.LoadScene(targetSceneName);
    }
    
    /// <summary>
    /// 异步加载目标场景
    /// </summary>
    public void LoadTargetSceneAsync()
    {
        if (string.IsNullOrEmpty(targetSceneName))
        {
            Debug.LogError("LoadSceneMgr: 目标场景名称为空！");
            return;
        }
        
        Debug.Log($"正在异步加载场景: {targetSceneName}");
        StartCoroutine(LoadSceneCoroutine(targetSceneName));
    }
    
    /// <summary>
    /// 异步加载场景的协程
    /// </summary>
    private IEnumerator LoadSceneCoroutine(string sceneName)
    {
        AsyncOperation asyncLoad = SceneManager.LoadSceneAsync(sceneName);
        
        // 等待场景加载完成
        while (!asyncLoad.isDone)
        {
            float progress = Mathf.Clamp01(asyncLoad.progress / 0.9f);
            Debug.Log($"场景加载进度: {progress * 100}%");
            yield return null;
        }
        
        Debug.Log($"场景 {sceneName} 加载完成！");
    }
    
    void Update()
    {
        
    }
}
