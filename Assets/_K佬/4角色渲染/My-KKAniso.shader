Shader "Custom/My-KKAniso"
// 各向异性高光
{
    Properties
    {
        _SpecShininess("Spec Shininess",Range(0.01,1000)) = 10
        _SpecIntensity("SpecIntensity",Range(0.01,5)) = 1.0
        _ShiftOffset("_ShiftOffset",Range(-1,1)) = 0
        _ShiftMap("_ShiftMap",2D) = "white"{}
        _NoiseIntensity("_NoiseIntensity",Range(0.01,5)) = 1.0
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
            float _ShiftOffset;
            float _NoiseIntensity;
            sampler2D _ShiftMap;
            float4 _ShiftMap_ST;

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
                half3 tangent_dir = normalize(i.tangent_dir);
                half3 binormal_dir = normalize(i.binormal_dir);

                half2 uv_shift = i.uv * _ShiftMap_ST.xy + _ShiftMap_ST.zw;
                half shiftNoise = tex2D(_ShiftMap, uv_shift).r;
                shiftNoise = (shiftNoise * 2.0 - 1.0) * _NoiseIntensity;
                half3 b_offset = normal_dir * (_ShiftOffset + shiftNoise);
                binormal_dir = normalize(binormal_dir + b_offset);
                half3 half_dir = normalize(light_dir + view_dir);
                half TdotH = dot(binormal_dir, half_dir);
                half sinTH = sqrt(1 - TdotH * TdotH);
                // half NdotH = dot(normal_dir, half_dir);
                half3 spec_color = pow(max(0.0, sinTH), _SpecShininess) * _LightColor0.xyz * _SpecIntensity;

                return half4(spec_color, 1.0);
            }
            ENDCG
        }
    }
}