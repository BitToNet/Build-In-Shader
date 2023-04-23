Shader "Custom/MyIBL"
{
    Properties
    {
        //        _MainTex ("Texture", 2D) = "white" {}
        _CubeMap("Cube Map",Cube) = "white"{}
        _Tint("Tint",Color) = (1,1,1,1)
        _Expose("Expose",Float) = 1.0
        _Rotate("Rotate",Range(0,360)) = 0
        _NormalMap("Normal Map",2D) = "bump"{}
        _NormalIntensity("Normal Intensity",Float) = 1.0
        _AOMap("AO Map",2D) = "white"{}
        _AOAdjust("AO Adjust",Range(0,1)) = 1
        _RoughnessMap("Roughness Map",2D) = "black"{}
        _RoughnessContrast("Roughness Contrast",Range(0.01,10)) = 1
        _RoughnessBrightness("Roughness Brightness",Float) = 1
        _RoughnessMin("Rough Min",Range(0,1)) = 0
        _RoughnessMax("Rough Max",Range(0,1)) = 1
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
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 pos : SV_POSITION;
                float3 normal_world : TEXCOORD1;
                float3 pos_world : TEXCOORD2;
                float3 tangent_world : TEXCOORD3;
                float3 binormal_world : TEXCOORD4;
            };

            // sampler2D _MainTex;
            // float4 _MainTex_ST;
            samplerCUBE _CubeMap;
            // 移动平台无法直接使用HDR，需要加一步解码操作
            float4 _CubeMap_HDR;
            float4 _Tint;
            float _Expose;

            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            float _NormalIntensity;
            sampler2D _AOMap;
            float _AOAdjust;
            float _Rotate;
            sampler2D _RoughnessMap;
            float _RoughnessContrast;
            float _RoughnessBrightness;
            float _RoughnessMin;
            float _RoughnessMax;

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

            inline float3 ACES_Tonemapping(float3 x)
            {
                float a = 2.51f;
                float b = 0.03f;
                float c = 2.43f;
                float d = 0.59f;
                float e = 0.14f;
                float3 encode_color = saturate((x * (a * x + b)) / (x * (c * x + d) + e));
                return encode_color;
            }

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord * _NormalMap_ST.xy + _NormalMap_ST.zw;
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.normal_world = normalize(mul(fixed4(v.normal, 0.0), unity_ObjectToWorld).xyz);
                o.tangent_world = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                o.binormal_world = normalize(cross(o.normal_world, o.tangent_world)) * v.tangent.w;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                // 法线方向
                float3 normal_dir = normalize(i.normal_world);
                // 采样发现贴图
                half3 normaldata = UnpackNormal(tex2D(_NormalMap, i.uv));
                normaldata.xy = normaldata.xy * _NormalIntensity;
                half3 tangent_dir = normalize(i.tangent_world);
                half3 binormal_dir = normalize(i.binormal_world);
                // 偏移法线
                normal_dir = normalize(tangent_dir * normaldata.x
                    + binormal_dir * normaldata.y + normal_dir * normaldata.z);
                // 灰度遮罩贴图，只取r，因为是黑白图
                half ao = tex2D(_AOMap, i.uv).r;
                ao = lerp(1.0, ao, _AOAdjust);
                // 视线方向
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                // 视线反射方向
                half3 reflect_dir = reflect(-view_dir, normal_dir);
                // 对反射方向做手动偏移，可以设置环境贴图内部的偏转
                reflect_dir = RotateAround(_Rotate, reflect_dir);

                // 添加粗糙度贴图
                float roughness = tex2D(_RoughnessMap, i.uv);
                // 增加粗糙度贴图的对比度、亮度
                roughness = saturate(pow(roughness, _RoughnessContrast) * _RoughnessBrightness);
                // 限制粗糙度范围
                roughness = lerp(_RoughnessMin, _RoughnessMax, roughness);
                // 抄unity代码，把线性变化改为有弧度的曲线
                roughness = roughness * (1.7 - 0.7 * roughness);
                // pbr里面一般是使用第六个层级
                float mip_level = roughness * 6.0;

                // 采样IBL环境贴图
                half4 color_cubemap = texCUBElod(_CubeMap, float4(reflect_dir, mip_level));
                // 确保在移动端能拿到HDR信息
                half3 env_color = DecodeHDR(color_cubemap, _CubeMap_HDR);

                half3 final_color = env_color * ao * _Tint.rgb * _Tint.rgb * _Expose;

                // 颜色空间转换
                half3 final_color_linear = pow(final_color, 2.2);
                final_color = ACES_Tonemapping(final_color_linear);
                half3 final_color_gamma = pow(final_color, 1.0 / 2.2);
                return float4(final_color_gamma, 1.0);
            }
            ENDCG
        }

    }
    FallBack "Diffuse"
}