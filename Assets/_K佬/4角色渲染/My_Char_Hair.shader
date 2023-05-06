Shader "Custom/My_Char_Hair"
{
    Properties
    {
        _BaseMap ("Texture", 2D) = "white" {}
        _BaseColor ("_BaseColor", Color) = (1,1,1,1)
        _NormalMap("NormalMap",2D) = "bump"{}
        _NormalIntensity("Normal Intensity（法线强度）",Range(0.0,5.0)) = 1.0

        [Header(Specular)]
        _AnisoMap("Aniso Map",2D) = "gray"{}
        _SpecColor1 ("_Spec Color 1", Color) = (1,1,1,1)
        _SpecShininess1("Spec Shininess 1",Range(0,1)) = 1
        _SpecNoise1("_Spec Noise 1",Float) = 1.0
        _SpecOffset1("_Spec Offset 1",Float) = 0

        _SpecColor2 ("_Spec Color 2", Color) = (1,1,1,1)
        _SpecShininess2("Spec Shininess 2",Range(0,1)) = 1
        _SpecNoise2("_Spec Noise 2",Float) = 1.0
        _SpecOffset2("_Spec Offset 2",Float) = 0

        _SpecIntensity("SpecIntensity",Range(0.01,5)) = 1.0

        _RoughnessAdjust("Roughness Adjust",Range(0,1)) = 0
        _MetalAdjust("Metal Adjust",Range(0,1)) = 0

        [Header(IBL)]
        _RoughnessContrast("Roughness Contrast",Range(0.01,10)) = 1
        _RoughnessBrightness("Roughness Brightness",Float) = 1
        _RoughnessMin("Rough Min",Range(0,1)) = 0
        _RoughnessMax("Rough Max",Range(0,1)) = 1
        _EnvSpecularMap("Env Specular Map",Cube) = "white"{}
        _Expose("Expose",Float) = 1.0
        _Rotate("Rotate",Range(0,360)) = 0


        [Toggle(_DIFFUSE_CHECK_ON)] _DIFFUSE_CHECK_ON("_DIFFUSE_CHECK_ON",Float) = 1.0
        [Toggle(_SPEC_CHECK_ON)] _SPEC_CHECK_ON("_SPEC_CHECK_ON",Float) = 1.0
        [Toggle(_IBL_CHECK_ON)] _IBL_CHECK_ON("_IBL_CHECK_ON",Float) = 1.0

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
            float4 _BaseColor;
            sampler2D _NormalMap;
            float4 _LightColor0;

            // Spec
            sampler2D _AnisoMap;
            float4 _AnisoMap_ST;
            float4 _SpecColor1;
            float _SpecShininess1;
            float _SpecNoise1;
            float _SpecOffset1;
            float4 _SpecColor2;
            float _SpecShininess2;
            float _SpecNoise2;
            float _SpecOffset2;


            float _SpecIntensity;
            float _RoughnessContrast;
            float _RoughnessBrightness;
            float _RoughnessMin;
            float _RoughnessMax;
            float _Rotate;

            samplerCUBE _EnvSpecularMap;
            // 移动平台无法直接使用HDR，需要加一步解码操作
            float4 _EnvSpecularMap_HDR;
            float _Expose;
            float _RoughnessAdjust;


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
                half4 albedo_color = pow(albedo_color_gamma, 2.2) * _BaseColor;
                half3 base_color = albedo_color.rgb;

                // 粗糙度信息：影响光滑度
                half roughness = saturate(_RoughnessAdjust);

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
                #ifdef _DIFFUSE_CHECK_ON
                half3 direct_diffuse = base_color;
                #else
                half3 direct_diffuse = half3(0.0,0.0,0.0);
                #endif


                // 直接光镜面反射
                half2 uv_aniso = i.uv * _AnisoMap_ST.xy + _AnisoMap_ST.zw;
                half aniso_noise = tex2D(_AnisoMap, uv_aniso).r - 0.5;

                half3 half_dir = normalize(light_dir + view_dir);
                half NdotH = dot(normal_dir, half_dir);
                half TdotH = dot(tangent_dir, half_dir);

                half NdotV = max(0.0, dot(view_dir, normal_dir));
                // 头发的阴影，边缘泛白
                float aniso_atten = saturate(sqrt(max(0.0, half_lambert / NdotV))) * atten;

                // spec1
                float3 spec_color1 = _SpecColor1.rgb + base_color;
                float3 aniso_offset1 = normal_dir * (aniso_noise * _SpecNoise1 + _SpecOffset1);
                float3 binormal_dir1 = normalize(binormal_dir + aniso_offset1);
                float BdotH1 = dot(half_dir, binormal_dir1) / _SpecShininess1;
                float3 spec_term1 = exp(-(TdotH * TdotH + BdotH1 * BdotH1) / (1.0 + NdotH));
                float3 final_spec1 = spec_term1 * aniso_atten * spec_color1 * _LightColor0.xyz;
                // spec2
                float3 spec_color2 = _SpecColor2.rgb + base_color;
                float3 aniso_offset2 = normal_dir * (aniso_noise * _SpecNoise2 + _SpecOffset2);
                float3 binormal_dir2 = normalize(binormal_dir + aniso_offset2);
                float BdotH2 = dot(half_dir, binormal_dir2) / _SpecShininess2;
                float3 spec_term2 = exp(-(TdotH * TdotH + BdotH2 * BdotH2) / (1.0 + NdotH));
                float3 final_spec2 = spec_term2 * aniso_atten * spec_color2 * _LightColor0.xyz;

                #ifdef _SPEC_CHECK_ON
                half3 direct_specular = final_spec1 + final_spec2;
                #else
                half3 direct_specular = half3(0.0,0.0,0.0);
                #endif

                // 增加粗糙度贴图的对比度、亮度
                roughness = saturate(pow(roughness, _RoughnessContrast) * _RoughnessBrightness);
                // 限制粗糙度范围
                roughness = lerp(_RoughnessMin, _RoughnessMax, roughness);
                // 抄unity代码，把线性变化改为有弧度的曲线
                roughness = roughness * (1.7 - 0.7 * roughness);
                // pbr里面一般是使用第六个层级
                float mip_level = roughness * 6.0;


                // 间接光镜面反射 IBL
                // 视线反射方向
                half3 reflect_dir = reflect(-view_dir, normal_dir);
                // 对反射方向做手动偏移，可以设置环境贴图内部的偏转
                reflect_dir = RotateAround(_Rotate, reflect_dir);
                // 采样IBL环境贴图
                half4 color_cubemap = texCUBElod(_EnvSpecularMap, float4(reflect_dir, mip_level));
                // 确保在移动端能拿到HDR信息
                half3 env_specular_color = DecodeHDR(color_cubemap, _EnvSpecularMap_HDR);
                #ifdef _IBL_CHECK_ON
                half3 env_specular = env_specular_color * _Expose * half_lambert * aniso_noise;
                #else
                half3 env_specular = half3(0.0,0.0,0.0);
                #endif

                // 最终加上环境光
                half3 final_color = (direct_diffuse * 5 + direct_specular + env_specular);
                // half3 final_color = direct_diffuse + final_spec1 + final_spec2 + env_specular;
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