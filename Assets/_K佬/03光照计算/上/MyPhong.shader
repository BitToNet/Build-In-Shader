Shader "Custom/Phong"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _NormalMap("NormalMap",2D) = "bump"{}
        _NormalIntensity("Normal Intensity（法线强度）",Range(0.0,5.0)) = 1.0
        _AOMap("AO Map",2D) = "white"{}
        _SpecMask("Spec Mask",2D) = "white"{}
        _Shininess("Shininess",Range(0.01,100)) = 1.0
        _SpecIntensity("SpecIntensity",Range(0.01,5)) = 1.0
        _ParallaxMap("ParallaxMap",2D) = "black"{}
        _Parallax("_Parallax",float) = 2
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
                // SHADOW_COORDS(5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _LightColor0;
            float _Shininess;
            float4 _AmbientColor;
            float _SpecIntensity;
            sampler2D _AOMap;
            sampler2D _SpecMask;
            sampler2D _NormalMap;
            float _NormalIntensity;
            // sampler2D _ParallaxMap;
            // float _Parallax;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.normal_dir = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
                // 切线
                o.tangent_dir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                // 副法线(法线和切线叉乘)  注：【* v.tangent.w】是处理不同平台翻转的问题
                o.binormal_dir = normalize(cross(o.normal_dir, o.tangent_dir)) * v.tangent.w;
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half4 base_color = tex2D(_MainTex, i.uv);
                half4 ao_color = tex2D(_AOMap, i.uv);
                half4 spec_mask = tex2D(_SpecMask, i.uv);
                half4 normalmap = tex2D(_NormalMap, i.uv);
                // 法线贴图的范围是从0到1，我们要改成-1到1，我们要做解码的操作
                float3 normal_data = UnpackNormal(normalmap);

                half3 normal_dir = normalize(i.normal_dir);
                half3 tangent_dir = normalize(i.tangent_dir);
                half3 binormal_dir = normalize(i.binormal_dir);
                // float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
                // normal_dir = normalize(mul(normal_data.xyz, TBN));
                normal_dir = normalize(
                    tangent_dir * normal_data.x * _NormalIntensity + binormal_dir * normal_data.y * _NormalIntensity +
                    normal_dir * normal_data.z);

                // 漫反射
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                half3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                half NdotL = dot(normal_dir, light_dir);
                half3 diffuse_color = max(0.0, NdotL) * _LightColor0.xyz * base_color.xyz;

                // 镜面反射
                half3 reflect_dir = reflect(-light_dir, normal_dir);
                half RdotV = dot(reflect_dir, view_dir);
                half3 spec_color = pow(max(0.0, RdotV), _Shininess) * _LightColor0.xyz * _SpecIntensity * spec_mask.rgb;

                // 最终加上环境光
                half3 final_color = (diffuse_color + spec_color + _AmbientColor.xyz) * ao_color;
                return half4(final_color, 1.0);
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
                // SHADOW_COORDS(5)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _LightColor0;
            float _Shininess;
            float4 _AmbientColor;
            float _SpecIntensity;
            sampler2D _AOMap;
            sampler2D _SpecMask;
            sampler2D _NormalMap;
            float _NormalIntensity;
            // sampler2D _ParallaxMap;
            // float _Parallax;

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.normal_dir = normalize(mul(float4(v.normal, 0.0), unity_WorldToObject).xyz);
                // 切线
                o.tangent_dir = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0.0)).xyz);
                // 副法线(法线和切线叉乘)  注：【* v.tangent.w】是处理不同平台翻转的问题
                o.binormal_dir = normalize(cross(o.normal_dir, o.tangent_dir)) * v.tangent.w;
                o.pos_world = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half4 base_color = tex2D(_MainTex, i.uv);
                half4 ao_color = tex2D(_AOMap, i.uv);
                half4 spec_mask = tex2D(_SpecMask, i.uv);
                half4 normalmap = tex2D(_NormalMap, i.uv);
                // 法线贴图的范围是从0到1，我们要改成-1到1，我们要做解码的操作
                float3 normal_data = UnpackNormal(normalmap);

                half3 normal_dir = normalize(i.normal_dir);
                half3 tangent_dir = normalize(i.tangent_dir);
                half3 binormal_dir = normalize(i.binormal_dir);
                // float3x3 TBN = float3x3(tangent_dir, binormal_dir, normal_dir);
                // normal_dir = normalize(mul(normal_data.xyz, TBN));
                normal_dir = normalize(
                    tangent_dir * normal_data.x * _NormalIntensity + binormal_dir * normal_data.y * _NormalIntensity +
                    normal_dir * normal_data.z);

                // 漫反射
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                #if defined(DIRECTIONAL)
                half3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                //衰减系数为1
                half attuenation = 1.0f;
                #elif defined(POINT)
                half3 light_dir = normalize(_WorldSpaceLightPos0.xyz-i.pos_world);
                half distance = length(_WorldSpaceLightPos0.xyz-i.pos_world);
                // 获取范围值，不用细究，后面用unity自带的范围值计算，而且他不是用这个方式
                half range = 1.0/unity_WorldToLight[0][0];
                half attuenation = saturate((range-distance)/range);
                #endif
                half NdotL = dot(normal_dir, light_dir);
                half3 diffuse_color = max(0.0, NdotL) * _LightColor0.xyz * base_color.xyz * attuenation;

                // 镜面反射
                half3 reflect_dir = reflect(-light_dir, normal_dir);
                half RdotV = dot(reflect_dir, view_dir);
                half3 spec_color = pow(max(0.0, RdotV), _Shininess) * _LightColor0.xyz * _SpecIntensity * spec_mask.rgb
                    * attuenation;

                // 最终加上环境光
                half3 final_color = (diffuse_color + spec_color) * ao_color;
                return half4(final_color, 1.0);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}