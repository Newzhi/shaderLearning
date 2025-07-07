// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/PBR Standard Shader" {
    Properties {
        // 基础属性
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Albedo Map", 2D) = "white" {}
        
        // 法线贴图
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Float) = 1.0
        
        // 遮罩贴图
        _MaskTex ("Mask Map", 2D) = "white" {}
        
        // 金属度贴图
        _MetallicMap ("Metallic Map", 2D) = "black" {}
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        
        // 粗糙度贴图
        _RoughnessMap ("Roughness Map", 2D) = "white" {}
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.5
        
        // 高光贴图
        _SpecularMap ("Specular Map", 2D) = "white" {}
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _SpecularScale ("Specular Scale", Float) = 1.0
        
        // 反射相关
        _ReflectionMap ("Reflection Map", 2D) = "black" {}
        _ReflectionIntensity ("Reflection Intensity", Range(0.0, 1.0)) = 0.5
        
        // 自发光
        _EmissionMap ("Emission Map", 2D) = "black" {}
        _EmissionColor ("Emission Color", Color) = (0, 0, 0, 1)
        _EmissionIntensity ("Emission Intensity", Float) = 1.0
        
        // 细节贴图
        _DetailMap ("Detail Map", 2D) = "white" {}
        _DetailScale ("Detail Scale", Float) = 1.0
    }
    
    SubShader {
        Tags { 
            "RenderType"="Opaque" 
            "Queue"="Geometry"
            "LightMode"="ForwardBase"
        }
        
        Pass { 
            Tags { "LightMode"="ForwardBase" }
        
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
            // 声明属性变量
            fixed4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            
            sampler2D _BumpMap;
            float _BumpScale;
            
            sampler2D _MaskTex;
            
            sampler2D _MetallicMap;
            float _Metallic;
            
            sampler2D _RoughnessMap;
            float _Roughness;
            
            sampler2D _SpecularMap;
            fixed4 _Specular;
            float _SpecularScale;
            
            sampler2D _ReflectionMap;
            float _ReflectionIntensity;
            
            sampler2D _EmissionMap;
            fixed4 _EmissionColor;
            float _EmissionIntensity;
            
            sampler2D _DetailMap;
            float _DetailScale;
            
            // 顶点着色器输入结构体
            struct a2v {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 texcoord : TEXCOORD0;
            };
            
            // 顶点着色器输出结构体
            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float3 worldNormal : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBinormal : TEXCOORD4;
                SHADOW_COORDS(5)
            };
            
            // 顶点着色器函数
            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                
                // 计算纹理坐标
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                
                // 计算世界空间位置
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                // 计算世界空间法线、切线和副切线
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBinormal = cross(o.worldNormal, o.worldTangent) * v.tangent.w;
                
                // 计算阴影坐标
                TRANSFER_SHADOW(o);
                
                return o;
            }
            
            // PBR光照计算函数
            float3 FresnelSchlick(float cosTheta, float3 F0) {
                return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
            }
            
            float DistributionGGX(float3 N, float3 H, float roughness) {
                float a = roughness * roughness;
                float a2 = a * a;
                float NdotH = max(dot(N, H), 0.0);
                float NdotH2 = NdotH * NdotH;
                
                float nom = a2;
                float denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = UNITY_PI * denom * denom;
                
                return nom / denom;
            }
            
            float GeometrySchlickGGX(float NdotV, float roughness) {
                float r = (roughness + 1.0);
                float k = (r * r) / 8.0;
                
                float nom = NdotV;
                float denom = NdotV * (1.0 - k) + k;
                
                return nom / denom;
            }
            
            float GeometrySmith(float3 N, float3 V, float3 L, float roughness) {
                float NdotV = max(dot(N, V), 0.0);
                float NdotL = max(dot(N, L), 0.0);
                float ggx2 = GeometrySchlickGGX(NdotV, roughness);
                float ggx1 = GeometrySchlickGGX(NdotL, roughness);
                
                return ggx1 * ggx2;
            }
            
            // 片段着色器函数
            fixed4 frag(v2f i) : SV_Target {
                // 采样各种贴图
                fixed4 albedo = tex2D(_MainTex, i.uv) * _Color;
                fixed4 mask = tex2D(_MaskTex, i.uv);
                fixed metallic = tex2D(_MetallicMap, i.uv).r * _Metallic;
                fixed roughness = tex2D(_RoughnessMap, i.uv).r * _Roughness;
                fixed4 specularMap = tex2D(_SpecularMap, i.uv) * _Specular * _SpecularScale;
                fixed4 reflectionMap = tex2D(_ReflectionMap, i.uv);
                fixed4 emissionMap = tex2D(_EmissionMap, i.uv);
                
                // 计算切线空间到世界空间的变换矩阵
                float3x3 tangentToWorld = float3x3(
                    normalize(i.worldTangent),
                    normalize(i.worldBinormal),
                    normalize(i.worldNormal)
                );
                
                // 采样法线贴图并转换到世界空间
                fixed3 normalTS = UnpackNormal(tex2D(_BumpMap, i.uv));
                normalTS.xy *= _BumpScale;
                normalTS.z = sqrt(1.0 - saturate(dot(normalTS.xy, normalTS.xy)));
                float3 normalWS = normalize(mul(normalTS, tangentToWorld));
                
                // 计算视角和光照方向
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 halfDir = normalize(lightDir + viewDir);
                
                // 计算基础光照参数
                float NdotL = max(dot(normalWS, lightDir), 0.0);
                float NdotV = max(dot(normalWS, viewDir), 0.0);
                float NdotH = max(dot(normalWS, halfDir), 0.0);
                
                // 计算F0（基础反射率）
                float3 F0 = lerp(0.04, albedo.rgb, metallic);
                
                // 计算Cook-Torrance BRDF
                float NDF = DistributionGGX(normalWS, halfDir, roughness);
                float G = GeometrySmith(normalWS, viewDir, lightDir, roughness);
                float3 F = FresnelSchlick(max(dot(halfDir, viewDir), 0.0), F0);
                
                float3 numerator = NDF * G * F;
                float denominator = 4.0 * NdotV * NdotL + 0.0001;
                float3 specular = numerator / denominator;
                
                // 计算漫反射
                float3 kS = F;
                float3 kD = (1.0 - kS) * (1.0 - metallic);
                float3 diffuse = kD * albedo.rgb / UNITY_PI;
                
                // 计算最终光照
                float3 Lo = (diffuse + specular) * _LightColor0.rgb * NdotL;
                
                // 添加环境光
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo.rgb;
                
                // 添加反射
                float3 reflection = reflectionMap.rgb * _ReflectionIntensity;
                
                // 添加自发光
                float3 emission = emissionMap.rgb * _EmissionColor.rgb * _EmissionIntensity;
                
                // 添加阴影
                fixed shadow = SHADOW_ATTENUATION(i);
                
                // 合并所有光照
                float3 finalColor = ambient + Lo * shadow + reflection + emission;
                
                return fixed4(finalColor, albedo.a);
            }
            
            ENDCG
        }
        
        // 阴影投射Pass
        Pass {
            Tags {"LightMode" = "ShadowCaster"}
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"
            
            struct v2f {
                V2F_SHADOW_CASTER;
            };
            
            v2f vert(appdata_base v) {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }
            
            fixed4 frag(v2f i) : SV_Target {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    } 
    
    FallBack "Diffuse"
}