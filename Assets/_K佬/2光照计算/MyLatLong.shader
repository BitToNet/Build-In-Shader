Shader "Custom/MyLatLong"
{
    Properties
    {
        //        _MainTex ("Texture", 2D) = "white" {}
        _PanoramaMap("Panorama Map",2D) = "white"{}
        _Tint("Tint",Color) = (1,1,1,1)
        _Expose("Expose",Float) = 1.0
        _Rotate("Rotate",Range(0,360)) = 0
        _NormalMap("Normal Map",2D) = "bump"{}
        _NormalIntensity("Normal Intensity",Float) = 1.0
        _AOMap("AO Map",2D) = "white"{}
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
            sampler2D _PanoramaMap;
            // 移动平台无法直接使用HDR，需要加一步解码操作
            float4 _PanoramaMap_HDR;
            float4 _Tint;
            float _Expose;

            sampler2D _NormalMap;
            float4 _NormalMap_ST;
            float _NormalIntensity;
            sampler2D _AOMap;
            float _Rotate;

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
                // 视线方向
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                // 视线反射方向
                half3 reflect_dir = reflect(-view_dir, normal_dir);
                // 对反射方向做手动偏移，可以设置环境贴图内部的偏转
                reflect_dir = RotateAround(_Rotate, reflect_dir);


                // // 采样环境贴图
                // half4 color_cubemap = texCUBE(_CubeMap, reflect_dir);
                // // 确保在移动端能拿到HDR信息
                // half3 env_color = DecodeHDR(color_cubemap, _CubeMap_HDR);

                // 整体：将3d反射向量转化为2d uv坐标，然后用2d的uv坐标采样全景图
                float3 normalizedCoords = normalize(reflect_dir);
                // 经纬度处理
                float latitude = acos(normalizedCoords.y);
                float longitude = atan2(normalizedCoords.z, normalizedCoords.x);
                float2 sphereCoords = float2(longitude, latitude) * float2(0.5 / UNITY_PI, 1.0 / UNITY_PI);
                float2 uv_panorama = float2(0.5, 1.0) - sphereCoords;

                half4 color_cubemap = tex2D(_PanoramaMap, uv_panorama);
                half3 env_color = DecodeHDR(color_cubemap, _PanoramaMap_HDR);


                half3 final_color = env_color * ao * _Tint.rgb * _Expose;
                return float4(final_color, 1.0);
            }
            ENDCG
        }

    }
    FallBack "Diffuse"
}