using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace BookEffect
{
    public class BookController : MonoBehaviour
    {
        //按钮
        public Button prev;
        public Button next;
        
        //根节点以及子对象（书页）
        private GameObject book;
        private GameObject[] pages;
        private int GameObjectCount;
        
        //材质相关
        public Texture[] textures;
        private Material[] materials;
        
        //每个页面的shader属性
        private float[] angle;
        private Vector4[] offset;
        private Texture[] frontTex;
        private Texture[] backTex;
        
        //页面间距
        private float _pageDistance = -0.01f;
        
        //翻页速度 点击角度
        public float FilpAngle = 5f;
        
        //翻页状态标志位
        private bool[] isFlipDone;
        
        //游标
        private int currentPageIndex = 0;
        
        // 长按控制
        private bool isPrevPressed = false;
        private bool isNextPressed = false;
        private float pressTimer = 0f;
        public float pressInterval = 0.05f; // 长按间隔时间（秒）

        #region Unity 生命周期

        void Start()
        {
            InitAll();
        }

        void Update()
        {
            OnBtnClicking();
        }

        #endregion
        
        #region 初始化

        //一次性初始化
        private void InitAll()
        {
            InitGameObject();
            InitMaterial();
            InitPageDistance();
            InitShaderPropertyGet();
            InitTextures();
            InitBtn();
        }

        //初始化游戏对象以及每个页面
        private void InitGameObject()
        {
            book = this.gameObject;
            GameObjectCount = book.transform.childCount;
            pages = new GameObject[GameObjectCount];
            
            //TODO 根据资源加载直接加载某个预制体作为书页，不需要人为复制粘贴预制体了
            //替换下面循环中的赋值语句，设置生成位置即可(需要生成在同一个位置，不然不能自动设置页面间距了)
            
            // 遍历所有子对象并赋值给pages数组
            for (int i = 0; i < GameObjectCount; i++)
            {
                pages[i] = book.transform.GetChild(i).gameObject;
            }
        }

        //初始化材质
        private void InitMaterial()
        {
            materials = new Material[GameObjectCount];
            for (int i = 0; i < GameObjectCount; i++)
            {
                MeshRenderer renderer = pages[i].GetComponent<MeshRenderer>();
                materials[i] = renderer.material;
            }
        }

        //初始化页面间距
        private void InitPageDistance()
        {
            for (int i = 0; i < GameObjectCount; i++)
            {
                pages[i].transform.position += new Vector3(0, i * _pageDistance ,0); //偏移书页模拟
            }
        }
        
        //初始化shader属性获取
        private void InitShaderPropertyGet()
        {
            angle = new float[GameObjectCount];
            offset = new Vector4[GameObjectCount];
            frontTex = new Texture[GameObjectCount];
            backTex = new Texture[GameObjectCount];
            isFlipDone = new bool[GameObjectCount];
            
            for (int i = 0; i < GameObjectCount; i++)
            {
                angle[i] = materials[i].GetFloat("_RotateAngle");
                offset[i] = materials[i].GetVector("_RotateOffset");
                frontTex[i] = materials[i].GetTexture("_FrontTex");
                backTex[i] = materials[i].GetTexture("_BackTex");
            }
        }

        //为每个页面赋值图片
        private void InitTextures()
        {
            if (textures == null || textures.Length == 0) return;
            
            for (int i = 0; i < GameObjectCount; i++)
            {
                if (materials[i] == null) continue;
                
                // 计算纹理索引：每个页面需要2个纹理（正面和背面）
                int frontTexIndex = i * 2;     // 正面纹理索引
                int backTexIndex = i * 2 + 1;  // 背面纹理索引
                
                // 设置正面纹理
                if (frontTexIndex < textures.Length && textures[frontTexIndex] != null)
                {
                        materials[i].SetTexture("_FrontTex", textures[frontTexIndex]);
                }
                
                // 设置背面纹理
                if (backTexIndex < textures.Length && textures[backTexIndex] != null)
                {
                        materials[i].SetTexture("_BackTex", textures[backTexIndex]);
                }
            }
        }
        //初始化按钮
        private void InitBtn()
        {
            // 为按钮添加EventTrigger组件来实现长按
            AddButtonEvents(prev, true);
            AddButtonEvents(next, false);
        }
        
       
        #endregion
        
        #region 按钮点击方法
        // 添加按钮事件
        void AddButtonEvents(Button button, bool isPrevButton)
        {
            // 获取或添加EventTrigger组件
            var trigger = button.gameObject.GetComponent<EventTrigger>() ?? 
                          button.gameObject.AddComponent<EventTrigger>();
            
            // 按下事件
            var pointerDown = new EventTrigger.Entry();
            pointerDown.eventID = EventTriggerType.PointerDown;
            pointerDown.callback.AddListener((data) => { OnButtonPressed(isPrevButton); });
            trigger.triggers.Add(pointerDown);
            
            // 抬起事件
            var pointerUp = new EventTrigger.Entry();
            pointerUp.eventID = EventTriggerType.PointerUp;
            pointerUp.callback.AddListener((data) => { OnButtonReleased(isPrevButton); });
            trigger.triggers.Add(pointerUp);
            
            // 离开事件（防止拖拽时卡住）
            var pointerExit = new EventTrigger.Entry();
            pointerExit.eventID = EventTriggerType.PointerExit;
            pointerExit.callback.AddListener((data) => { OnButtonReleased(isPrevButton); });
            trigger.triggers.Add(pointerExit);
        }
        
        // 按钮按下
        void OnButtonPressed(bool isPrevButton)
        {
            if (isPrevButton) 
            {
                isPrevPressed = true;
                //Debug.Log("上一页按钮按下");
            }
            else 
            {
                isNextPressed = true;
                //Debug.Log("下一页按钮按下");
            }
            pressTimer = 0f;
        }
        
        // 按钮抬起
        void OnButtonReleased(bool isPrevButton)
        {
            if (isPrevButton) 
            {
                isPrevPressed = false;
                //Debug.Log("上一页按钮抬起");
            }
            else 
            {
                isNextPressed = false;
                //Debug.Log("下一页按钮抬起");
            }
        }

        private void OnPrevBtnClick()
        {
            // 如果当前页面角度为0，游标移动到上一页
            if (angle[currentPageIndex] <= 0f)
            {
                if (currentPageIndex > 0)
                {
                    currentPageIndex--;
                    //Debug.Log($"游标移动到页面 {currentPageIndex}");
                }
            }
            else
            {
                // 当前页面有角度，继续翻回
                angle[currentPageIndex] -= FilpAngle;
                angle[currentPageIndex] = Mathf.Clamp(angle[currentPageIndex], 0f, 180f);
                materials[currentPageIndex].SetFloat("_RotateAngle", angle[currentPageIndex]);
                
                // 更新页面位置
                UpdatePagePosition(currentPageIndex);
            }
        }

        private void OnNextBtnClick()
        {
            // 如果当前页面角度为180，游标移动到下一页
            if (angle[currentPageIndex] >= 180f)
            {
                if (currentPageIndex < GameObjectCount - 1)
                {
                    currentPageIndex++;
                    //Debug.Log($"游标移动到页面 {currentPageIndex}");
                }
            }
            else
            {
                // 当前页面未完全翻过，继续翻动
                angle[currentPageIndex] += FilpAngle;
                angle[currentPageIndex] = Mathf.Clamp(angle[currentPageIndex], 0f, 180f);
                materials[currentPageIndex].SetFloat("_RotateAngle", angle[currentPageIndex]);
                
                // 更新页面位置
                UpdatePagePosition(currentPageIndex);
            }
        }
        
        // 更新页面位置：随着角度增加，位置越靠近最后一页
        private void UpdatePagePosition(int pageIndex)
        {
            if (pageIndex < 0 || pageIndex >= GameObjectCount) return;
            
            // 计算位置偏移：角度越大，越靠近最后一页的位置
            float angleRatio = angle[pageIndex] / 180f; // 0-1的比例
            float targetY = (GameObjectCount - 1 - pageIndex) * _pageDistance; // 最后一页的Y位置
            float currentY = pageIndex * _pageDistance; // 当前页面的原始Y位置
            
            // 插值计算：从原始位置移动到最后一页位置
            float newY = Mathf.Lerp(currentY, targetY, angleRatio);
            
            // 更新位置
            Vector3 currentPos = pages[pageIndex].transform.position;
            pages[pageIndex].transform.position = new Vector3(currentPos.x, newY, currentPos.z);
        }

        private void OnBtnClicking()
        {
            // 处理长按逻辑
            if (isPrevPressed || isNextPressed)
            {
                pressTimer += Time.deltaTime;
                
                if (pressTimer >= pressInterval)
                {
                    pressTimer = 0f; // 重置计时器
                    
                    if (isPrevPressed)
                    {
                        OnPrevBtnClick();
                    }
                    else if (isNextPressed)
                    {
                        OnNextBtnClick();
                    }
                }
            }
        }
        
        #endregion
    }
}

//位置相关：随着翻转角度增加  位置也会越靠近最后一页  也就是书所在平面
//当前页面游标：如果角度属性是180  那么标记已经翻过了，游标到下一个页面索引处
//按钮点击方法：点击next设置游标所在的游戏对象的角度属性增加，点击prev设置游标所在游戏对象的角度属性减少（0-180范围内）
//如果当前角度是0度，同时点击了prev，游标上移到上一个页面，设置其角度减少（180度减少到0），也就是分为从前往后翻书和从后往前翻书
