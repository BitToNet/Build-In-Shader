Shader "Custom/My_Char_Standard"
{
    Properties
    {
        [Toggle(_DIFFUSE_CHECK_ON)] _DIFFUSE_CHECK_ON("_DIFFUSE_CHECK_ON",Float) = 1.0
        [Toggle(_SPEC_CHECK_ON)] _SPEC_CHECK_ON("_SPEC_CHECK_ON",Float) = 1.0
        [Toggle(_SH_CHECK_ON)] _SH_CHECK_ON("_SH_CHECK_ON",Float) = 1.0
        [Toggle(_IBL_CHECK_ON)] _IBL_CHECK_ON("_IBL_CHECK_ON",Float) = 1.0
        
        _BaseMap ("Texture", 2D) = "white" {}
        _CompMap ("_CompMap(RM-粗糙度、金属度)", 2D) = "white" {}
        _NormalMap("NormalMap",2D) = "bump"{}
        _NormalIntensity("法线强度",Range(0.0,5.0)) = 1.0
        [Header(Spec)]
        _SpecShininess("对比度",Range(0.01,100)) = 10
        _SpecIntensity("强度",Range(0.01,5)) = 1.0

        _RoughnessAdjust("粗糙度校准",Range(-1,1)) = 0
        _MetalAdjust("金属度校准",Range(-1,1)) = 0

        _EnvDiffuseMap("Env Diffuse Map",Cube) = "white"{}
        _EnvDiffuseMapExpose("漫反射曝光",Float) = 1.0
        _SkinLUT("皮肤查找表",2D) = "white"{}
        _LutOffset("_LutOffset",Range(-1,1)) = 0

        [Header(IBL)]
        _EnvSpecularMap("Env Specular Map",Cube) = "white"{}
        _EnvSpecularMapExpose("镜面反射曝光",Float) = 1.0




        [HideInInspector]custom_SHAr("Custom SHAr", Vector) = (0, 0, 0, 0)
        [HideInInspector]custom_SHAg("Custom SHAg", Vector) = (0, 0, 0, 0)
        [HideInInspector]custom_SHAb("Custom SHAb", Vector) = (0, 0, 0, 0)
        [HideInInspector]custom_SHBr("Custom SHBr", Vector) = (0, 0, 0, 0)
        [HideInInspector]custom_SHBg("Custom SHBg", Vector) = (0, 0, 0, 0)
        [HideInInspector]custom_SHBb("Custom SHBb", Vector) = (0, 0, 0, 0)
        [HideInInspector]custom_SHC("Custom SHC", Vector) = (0, 0, 0, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "ForwardBase"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase
            #pragma shader_feature _DIFFUSE_CHECK_ON
            #pragma shader_feature _SPEC_CHECK_ON
            #pragma shader_feature _SH_CHECK_ON
            #pragma shader_feature _IBL_CHECK_ON

            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normal_dir : TEXCOORD1;
                float3 pos_world : TEXCOORD2;
                float3 tangent_dir : TEXCOORD3;
                float3 binormal_dir : TEXCOORD4;
                LIGHTING_COORDS(5, 6)
            };

            sampler2D _BaseMap;
            sampler2D _CompMap;
            sampler2D _NormalMap;
            float4 _LightColor0;
            float _SpecShininess;
            float _SpecIntensity;
            samplerCUBE _EnvSpecularMap;
            // 移动平台无法直接使用HDR，需要加一步解码操作
            float4 _EnvSpecularMap_HDR;
            float _EnvSpecularMapExpose;
            float _EnvDiffuseMapExpose;
            float _RoughnessAdjust;
            float _MetalAdjust;
            samplerCUBE _EnvDiffuseMap;
            // 移动平台无法直接使用HDR，需要加一步解码操作
            float4 _EnvDiffuseMap_HDR;
            sampler2D _SkinLUT;
            float _LutOffset;

            half4 custom_SHAr;
            half4 custom_SHAg;
            half4 custom_SHAb;
            half4 custom_SHBr;
            half4 custom_SHBg;
            half4 custom_SHBb;
            half4 custom_SHC;

            // 计算自定义球谐光照
            float3 custom_sh(float3 normal_dir)
            {
                float4 normalForSH = float4(normal_dir, 1.0);
                //SHEvalLinearL0L1
                half3 x;
                x.r = dot(custom_SHAr, normalForSH);
                x.g = dot(custom_SHAg, normalForSH);
                x.b = dot(custom_SHAb, normalForSH);

                //SHEvalLinearL2
                half3 x1, x2;
                // 4 of the quadratic (L2) polynomials
                half4 vB = normalForSH.xyzz * normalForSH.yzzx;
                x1.r = dot(custom_SHBr, vB);
                x1.g = dot(custom_SHBg, vB);
                x1.b = dot(custom_SHBb, vB);

                // Final (5th) quadratic (L2) polynomial
                half vC = normalForSH.x * normalForSH.x - normalForSH.y * normalForSH.y;
                x2 = custom_SHC.rgb * vC;

                float3 sh = max(float3(0.0, 0.0, 0.0), (x + x1 + x2));
                sh = pow(sh, 1.0 / 2.2);
                return sh;
            }

            float3 ACESFilm(float3 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
            }

            float3 RotateAround(float degree, float3 target)
            {
                // 角度转弧度
                float rad = degree * UNITY_PI / 180;
                // 旋转矩阵
                float2x2 m_rotate = float2x2(cos(rad), -sin(rad),
                                             sin(rad), cos(rad));
                // 对xz旋转
                float2 dir_rotate = mul(m_rotate, target.xz);
                target = float3(dir_rotate.x, target.y, dir_rotate.y);
                return target;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                o.normal_dir = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
                // 切线
                o.tangent_dir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                // 副法线(法线和切线叉乘)  注：【* v.tangent.w】是处理不同平台翻转的问题
                o.binormal_dir = normalize(cross(o.normal_dir, o.tangent_dir)) * v.tangent.w;
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                TRANSFER_VERTEX_TO_FRAGMENT(o);

                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half4 albedo_color_gamma = tex2D(_BaseMap, i.uv);
                half4 albedo_color = pow(albedo_color_gamma, 2.2);
                half4 comp_mask = tex2D(_CompMap, i.uv);

                // 金属度信息
                half metal = saturate(comp_mask.g + _MetalAdjust);
                float3 base_color = albedo_color.rgb * (1 - metal); // 非金属固有色，金属没有漫反射
                float3 spec_color = lerp(0.04, albedo_color, metal); // 高光颜色

                // 粗糙度信息：影响光滑度
                half roughness = saturate(comp_mask.r + _RoughnessAdjust);

                // 皮肤区域
                half skin_area = 1.0 - comp_mask.b;

                // 法线贴图的范围是从0到1，我们要改成-1到1，我们要做解码的操作
                float3 normal_data = UnpackNormal(tex2D(_NormalMap, i.uv));

                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                half3 normal_dir = normalize(i.normal_dir);
                half3 tangent_dir = normalize(i.tangent_dir);
                half3 binormal_dir = normalize(i.binormal_dir);
                float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
                normal_dir = normalize(mul(normal_data.xyz, TBN));

                half3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                half atten = LIGHT_ATTENUATION(i);

                // 直接光漫反射
                // 比较阴影和漫反射，哪个更暗取哪个
                half diff_term = max(0.0, dot(normal_dir, light_dir));
                half half_lambert = (diff_term + 1.0) * 0.5;
                half3 common_diffuse = diff_term * base_color * atten * _LightColor0.xyz;
                // 皮肤效果
                half2 uv_lut = half2(diff_term * atten + _LutOffset, 1.0);
                half3 lut_color_gamma = tex2D(_SkinLUT, uv_lut);
                half3 lut_color = pow(lut_color_gamma, 2.2);
                half3 sss_diffuse = lut_color * base_color * _LightColor0.xyz * half_lambert;
                #ifdef _DIFFUSE_CHECK_ON
                half3 direct_diffuse = lerp(common_diffuse, sss_diffuse, skin_area);
                #else
                half3 direct_diffuse = half3(0.0,0.0,0.0);
                #endif


                // 直接光镜面反射
                half3 half_dir = normalize(light_dir + view_dir);
                half NdotH = dot(normal_dir, half_dir);
                half smoothness = 1.0 - roughness;
                // 最后*smoothness是作者加的经验值
                half spec_term = pow(max(0.0, NdotH), lerp(1, _SpecShininess, smoothness) * smoothness);
                // 皮肤油光效果
                half3 spec_skin_color = lerp(spec_color, 0.2, skin_area);
                #ifdef _SPEC_CHECK_ON
                half3 direct_specular = spec_term * spec_skin_color * _LightColor0.xyz * _SpecIntensity * atten;
                #else
                half3 direct_specular = half3(0.0,0.0,0.0);
                #endif

                // 间接光漫反射 SH
                // float3 env_diffuse = custom_sh(normal_dir) * base_color * half_lambert;
                // 采样IBL环境贴图
                // 抄unity代码，把线性变化改为有弧度的曲线
                roughness = roughness * (1.7 - 0.7 * roughness);
                // pbr里面一般是使用第六个层级
                float mip_level = roughness * 6.0;
                half4 color_diffuse_cubemap = texCUBElod(_EnvDiffuseMap, float4(normal_dir, mip_level));
                // 确保在移动端能拿到HDR信息
                half3 env_diffuse_color = DecodeHDR(color_diffuse_cubemap, _EnvDiffuseMap_HDR);
                half3 env_diffuse = env_diffuse_color * _EnvDiffuseMapExpose * base_color * half_lambert;
                #ifdef _SH_CHECK_ON
                // 提亮皮肤
                env_diffuse = lerp(env_diffuse * 0.5, env_diffuse, skin_area);
                #else
                env_diffuse = half3(0.0,0.0,0.0);
                #endif


                // 间接光镜面反射 IBL
                // 视线反射方向
                half3 reflect_dir = reflect(-view_dir, normal_dir);
                // 采样IBL环境贴图
                half4 color_cubemap = texCUBElod(_EnvSpecularMap, float4(reflect_dir, mip_level));
                // 确保在移动端能拿到HDR信息
                half3 env_specular_color = DecodeHDR(color_cubemap, _EnvSpecularMap_HDR);
                #ifdef _IBL_CHECK_ON
                half3 env_specular = env_specular_color * _EnvSpecularMapExpose * spec_color * half_lambert;
                #else
                half3 env_specular = half3(0.0,0.0,0.0);
                #endif

                // 最终加上环境光
                half3 final_color = (direct_diffuse + direct_specular + env_diffuse + env_specular);
                half3 tone_color = ACESFilm(final_color);
                tone_color = pow(tone_color, 1.0 / 2.2);

                return half4(tone_color, 1.0);
                // return base_color;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}