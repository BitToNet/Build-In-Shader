Shader "Custom/MyDragon"
{
    Properties
    {
        _DiffuseColor("漫反射颜色",Color) = (0,0.352,0.219,1)
        _AddColor("补色",Color) = (0,0.352,0.219,1)
        _Opacity("天光强度",Range(0,1)) = 0
        _ThicknessMap("厚度贴图",2D) = "black"{}

        [Header(BasePass)]
        _BasePassDistortion("Bass Pass Distortion", Range(0,1)) = 0.2
        _BasePassColor("BasePass Color",Color) = (1,1,1,1)
        _BasePassPower("BasePass Power",float) = 1
        _BasePassScale("BasePass Scale",float) = 2

        [Header(AddPass)]
        _AddPassDistortion("Add Pass Distortion", Range(0,1)) = 0.2
        _AddPassColor("AddPass Color",Color) = (0.56,0.647,0.509,1)
        _AddPassPower("AddPass Power",float) = 1
        _AddPassScale("AddPass Scale",float) = 1

        [Header(EnvReflect)]
        _EnvRotate("Env Rotate",Range(0,360)) = 0
        _EnvMap ("Env Map", Cube) = "white" {}
        _FresnelMin("Fresnel Min",Range(-2,2)) = 0
        _FresnelMax("Fresnel Max",Range(-2,2)) = 1
        _EnvIntensity("Env Intensity",float) = 1.0
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
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            sampler2D _ThicknessMap;
            float4 _DiffuseColor;
            float4 _AddColor;
            float _Opacity;

            float4 _BasePassColor;
            float _BasePassDistortion;
            float _BasePassPower;
            float _BasePassScale;

            samplerCUBE _EnvMap;
            float4 _EnvMap_HDR;
            float _EnvRotate;
            float _EnvIntensity;
            float _FresnelMin;
            float _FresnelMax;

            float4 _LightColor0;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                float3 normalDir : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;


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
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.texcoord;
                o.pos = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 normalDir = normalize(i.normalDir);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);

                // 添加漫反射，没有贴图用固有色替代
                float3 diffuse_color = _DiffuseColor.xyz;
                float diffuse_term = max(0.0, dot(normalDir, lightDir));
                // 漫反射强度*颜色*光强
                float3 diffuselight = diffuse_term * diffuse_color * _LightColor0.xyz;

                // 加天光效果
                float sky_light = (dot(normalDir, float3(0, 1, 0)) + 1.0) * 0.5;
                float3 sky_lightcolor = sky_light * diffuse_color * _Opacity;

                // 补色
                float3 final_diffuse = diffuselight + sky_lightcolor + _AddColor.xyz;

                // 漫反射演变透射光
                // float NdotL = max(0.0, dot(normalDir, lightDir));
                // 用法线扭曲，形成折射效果
                float3 back_dir = -normalize(lightDir + normalDir * _BasePassDistortion);
                // 光线与实现平行就透射
                float VdotB = max(0.0, dot(viewDir, back_dir));
                // 增加变化陡峭度，加入强度和对比度
                float backlight_term = max(0.0, pow(VdotB, _BasePassPower)) * _BasePassScale;
                // 添加厚度，颜色越黑的地方越透
                float thickness = 1.0 - tex2D(_ThicknessMap, i.uv).r;
                float3 backlight = backlight_term * _LightColor0.xyz * thickness * _BasePassColor.xyz;

                // 光泽反射
                float3 reflect_dir = reflect(-viewDir, normalDir);
                // 对反射方向做手动偏移，可以设置环境贴图内部的偏转
                reflect_dir = RotateAround(_EnvRotate, reflect_dir);
                // 用反色向量采样环境贴图
                float4 hdr_color = texCUBE(_EnvMap, reflect_dir);
                // hdr 解码信息
                float3 env_color = DecodeHDR(hdr_color, _EnvMap_HDR);
                // 加上菲涅尔效果
                float fresnel = 1.0 - max(0.0, dot(normalDir, viewDir));
                float final_env = env_color * fresnel;

                float3 final_color = backlight + final_env + final_diffuse;

                return float4(final_color, 1.0);
            }
            ENDCG
        }

        Pass
        {
            Tags
            {
                "LightMode" = "ForwardAdd"
            }
            Blend One One
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            float4 _LightColor0;

            float4 _DiffuseColor;
            sampler2D _ThicknessMap;
            float _AddPassDistortion;
            float _AddPassPower;
            float _AddPassScale;
            float4 _AddPassColor;

            samplerCUBE _EnvMap;
            float _EnvIntensity;
            float _FresnelMin;
            float _FresnelMax;


            struct appdata
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 posWorld : TEXCOORD1;
                float3 normalDir : TEXCOORD2;
                LIGHTING_COORDS(3, 4)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;


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
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.normalDir = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.texcoord;
                o.pos = UnityObjectToClipPos(v.vertex);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                half atten = LIGHT_ATTENUATION(i);
                float3 normalDir = normalize(i.normalDir);
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.posWorld.xyz);

                // 区分点光源
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 light_dir_other = normalize(_WorldSpaceLightPos0.xyz - i.posWorld);
                lightDir = lerp(lightDir, light_dir_other, _WorldSpaceLightPos0.w);

                // 漫反射演变透射光
                // float NdotL = max(0.0, dot(normalDir, lightDir));
                // 用法线扭曲，形成折射效果
                float3 back_dir = -normalize(lightDir + normalDir * _AddPassDistortion);
                // 光线与实现平行就透射
                float VdotB = max(0.0, dot(viewDir, back_dir));
                // 增加变化陡峭度，加入强度和对比度
                float backlight_term = max(0.0, pow(VdotB, _AddPassPower)) * _AddPassScale;
                // 添加厚度，颜色越黑的地方越透
                float thickness = 1.0 - tex2D(_ThicknessMap, i.uv).r;
                float3 backlight = backlight_term * _LightColor0.xyz * thickness * _AddPassColor.xyz * atten;

                float3 final_color = backlight;

                return float4(final_color, 1.0);
            }
            ENDCG
        }
    }
}