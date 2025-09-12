using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class bookController : MonoBehaviour
{
    #region 公共属性
    public Button prev;
    public Button next;
    public GameObject[] pages;
    public Texture[] textures;
    public Material[] materials;
    public Texture defaultTexture;
    public float PageDistance = 0.05f;
    #endregion

    #region 私有属性
    private int currentPageIndex = 0;
    private List<PageData> pageDataList = new List<PageData>();
    private int flipCounter = 0;
    
    // 长按控制
    private bool isPrevPressed = false;
    private bool isNextPressed = false;
    private float pressTimer = 0f;
    private float pressInterval = 0.1f;
    #endregion

    #region 数据结构
    [System.Serializable]
    public class PageData
    {
        public GameObject pageObject;
        public Material pageMaterial;
        public float currentAngle;
        public bool isFlipped;
        public int flipOrder;
        
        public PageData(GameObject obj, Material mat)
        {
            pageObject = obj;
            pageMaterial = mat;
            currentAngle = 0f;
            isFlipped = false;
            flipOrder = -1;
        }
    }
    #endregion

    #region Unity生命周期
    void Start()
    {
        prev = prev.GetComponent<Button>();
        next = next.GetComponent<Button>();

        AddButtonEvents(prev, true);
        AddButtonEvents(next, false);

        GetChildPages();
        AssignTexturesToMaterials();
        InitializePageData();
        SetupPagesPosition();
    }
    
    void Update()
    {
        if (isPrevPressed || isNextPressed)
        {
            pressTimer += Time.deltaTime;
            if (pressTimer >= pressInterval)
            {
                pressTimer = 0f;
                if (isPrevPressed) OnPrevButtonClick();
                else if (isNextPressed) OnNextButtonClick();
            }
        }
    }
    #endregion

    #region 页面和材质管理
    void GetChildPages()
    {
        List<GameObject> childPages = new List<GameObject>();
        for (int i = 0; i < transform.childCount; i++)
        {
            childPages.Add(transform.GetChild(i).gameObject);
        }
        pages = childPages.ToArray();
        GetChildMaterials();
    }
    
    void GetChildMaterials()
    {
        if (pages == null || pages.Length == 0) return;
        
        List<Material> childMaterials = new List<Material>();
        foreach (GameObject page in pages)
        {
            MeshRenderer renderer = page.GetComponent<MeshRenderer>();
            childMaterials.Add(renderer?.material);
        }
        materials = childMaterials.ToArray();
    }

    void AssignTexturesToMaterials()
    {
        if (materials == null || materials.Length == 0) return;

        for (int i = 0; i < materials.Length; i++)
        {
            if (materials[i] == null) continue;

            int frontTexIndex = i * 2;
            int backTexIndex = i * 2 + 1;

            Texture frontTex = GetTextureByIndex(frontTexIndex);
            Texture backTex = GetTextureByIndex(backTexIndex);

            if (materials[i].HasProperty("_FrontTex"))
                materials[i].SetTexture("_FrontTex", frontTex);
            if (materials[i].HasProperty("_BackTex"))
                materials[i].SetTexture("_BackTex", backTex);
        }
    }

    Texture GetTextureByIndex(int index)
    {
        if (textures != null && index >= 0 && index < textures.Length && textures[index] != null)
            return textures[index];
        return defaultTexture;
    }
    #endregion

    #region 书页数据管理
    void InitializePageData()
    {
        pageDataList.Clear();
        for (int i = 0; i < pages.Length && i < materials.Length; i++)
        {
            if (pages[i] != null && materials[i] != null)
            {
                PageData pageData = new PageData(pages[i], materials[i]);
                if (materials[i].HasProperty("_RotateAngle"))
                {
                    pageData.currentAngle = materials[i].GetFloat("_RotateAngle");
                    pageData.isFlipped = pageData.currentAngle >= 180f;
                }
                pageDataList.Add(pageData);
            }
        }
    }
    
    void UpdatePageAngle(int pageIndex, float deltaAngle)
    {
        if (pageIndex < 0 || pageIndex >= pageDataList.Count) return;
        
        PageData pageData = pageDataList[pageIndex];
        bool wasFlipped = pageData.isFlipped;
        
        pageData.currentAngle = Mathf.Clamp(pageData.currentAngle + deltaAngle, 0f, 180f);
        pageData.isFlipped = pageData.currentAngle >= 180f;
        
        if (pageData.pageMaterial?.HasProperty("_RotateAngle") == true)
            pageData.pageMaterial.SetFloat("_RotateAngle", pageData.currentAngle);
        
        if (wasFlipped != pageData.isFlipped)
        {
            if (pageData.isFlipped)
                pageData.flipOrder = flipCounter++;
            else
                pageData.flipOrder = -1;
            
            RearrangePagesPosition();
        }
    }
    #endregion

    #region 页面位置管理
    void SetupPagesPosition()
    {
        if (pages == null || pages.Length == 0) return;

        for (int i = 0; i < pages.Length; i++)
        {
            if (pages[i] != null)
            {
                pages[i].transform.position = CalculatePageTargetPosition(i);
            }
        }
    }
    
    Vector3 CalculatePageTargetPosition(int pageIndex)
    {
        Vector3 basePosition = pages[0].transform.position;
        int totalPages = pages.Length;
        int positionIndex = pageIndex < totalPages / 2 ? pageIndex : totalPages - 1 - pageIndex;
        float yOffset = positionIndex * PageDistance;
        return new Vector3(basePosition.x, basePosition.y + yOffset, basePosition.z);
    }
    
    void RearrangePagesPosition()
    {
        if (pages == null || pages.Length == 0 || pageDataList.Count == 0) return;
        
        foreach (PageData pageData in pageDataList)
        {
            if (pageData.pageObject != null)
            {
                int originalIndex = GetPageOriginalIndex(pageData.pageObject);
                Vector3 targetPosition = pageData.isFlipped ? 
                    CalculateFlippedPagePosition(originalIndex) : 
                    CalculatePageTargetPosition(originalIndex);
                pageData.pageObject.transform.position = targetPosition;
            }
        }
    }
    
    int GetPageOriginalIndex(GameObject pageObject)
    {
        for (int i = 0; i < pages.Length; i++)
        {
            if (pages[i] == pageObject) return i;
        }
        return -1;
    }
    
    Vector3 CalculateFlippedPagePosition(int originalIndex)
    {
        Vector3 basePosition = pages[0].transform.position;
        int targetPositionIndex = pages.Length - 1 - originalIndex;
        float yOffset = targetPositionIndex * PageDistance;
        return new Vector3(basePosition.x, basePosition.y + yOffset, basePosition.z);
    }
    #endregion

    #region 按钮事件处理
    void OnPrevButtonClick()
    {
        UpdatePageAngle(currentPageIndex, -10f);
        if (pageDataList[currentPageIndex].currentAngle <= 0 && currentPageIndex > 0)
        {
            currentPageIndex--;
        }
    }
    
    void OnNextButtonClick()
    {
        UpdatePageAngle(currentPageIndex, 10f);
        if (pageDataList[currentPageIndex].isFlipped && currentPageIndex < pageDataList.Count - 1)
        {
            currentPageIndex++;
        }
    }
    #endregion
    
    #region 长按控制
    void AddButtonEvents(Button button, bool isPrevButton)
    {
        var trigger = button.gameObject.GetComponent<UnityEngine.EventSystems.EventTrigger>() ?? 
                     button.gameObject.AddComponent<UnityEngine.EventSystems.EventTrigger>();
        
        var pointerDown = new UnityEngine.EventSystems.EventTrigger.Entry();
        pointerDown.eventID = UnityEngine.EventSystems.EventTriggerType.PointerDown;
        pointerDown.callback.AddListener((data) => { OnButtonPressed(isPrevButton); });
        trigger.triggers.Add(pointerDown);
        
        var pointerUp = new UnityEngine.EventSystems.EventTrigger.Entry();
        pointerUp.eventID = UnityEngine.EventSystems.EventTriggerType.PointerUp;
        pointerUp.callback.AddListener((data) => { OnButtonReleased(isPrevButton); });
        trigger.triggers.Add(pointerUp);
        
        var pointerExit = new UnityEngine.EventSystems.EventTrigger.Entry();
        pointerExit.eventID = UnityEngine.EventSystems.EventTriggerType.PointerExit;
        pointerExit.callback.AddListener((data) => { OnButtonReleased(isPrevButton); });
        trigger.triggers.Add(pointerExit);
    }
    
    void OnButtonPressed(bool isPrevButton)
    {
        if (isPrevButton) isPrevPressed = true;
        else isNextPressed = true;
        pressTimer = 0f;
    }
    
    void OnButtonReleased(bool isPrevButton)
    {
        if (isPrevButton) isPrevPressed = false;
        else isNextPressed = false;
    }
    #endregion
}
