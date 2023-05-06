Shader "Custom/My-Blin-Phong"
{
    Properties
    {
        _SpecShininess("Spec Shininess",Range(0.01,100)) = 10
        _SpecIntensity("SpecIntensity",Range(0.01,5)) = 1.0
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
                LIGHTING_COORDS(5, 6)
            };

            float4 _LightColor0;
            float _SpecShininess;
            float _SpecIntensity;

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
                return o;
            }

            half4 frag(v2f i) : SV_Target
            {
                half3 light_dir = normalize(_WorldSpaceLightPos0.xyz);
                half3 view_dir = normalize(_WorldSpaceCameraPos.xyz - i.pos_world);
                half3 normal_dir = normalize(i.normal_dir);

                half3 half_dir = normalize(light_dir + view_dir);
                half NdotH = dot(normal_dir, half_dir);
                half3 spec_color = pow(max(0.0, NdotH), _SpecShininess) * _LightColor0.xyz * _SpecIntensity;
                
                return half4(spec_color, 1.0);
            }
            ENDCG
        }
    }
}