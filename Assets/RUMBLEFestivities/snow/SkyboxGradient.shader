Shader "Skybox/VerticalGradient"
{
    Properties
    {
        _ColorBottom ("Bottom Color", Color) = (0.0, 0.0, 0.5, 1.0)
        _ColorTop ("Top Color", Color) = (0.5, 0.7, 1.0, 1.0)
        _HeightStart ("Gradient Start Height", Float) = -1.0
        _HeightStop ("Gradient Stop Height", Float) = 1.0
    }
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Opaque" }
        Cull Off
        ZWrite Off
        ZTest LEqual

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float3 dir : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float4 _ColorBottom;
            float4 _ColorTop;
            float _HeightStart;
            float _HeightStop;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.dir = v.vertex.xyz; // direction vector
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Normalize direction to get "sky direction"
                float3 dir = normalize(i.dir);

                // Use Y component for vertical gradient
                float t = saturate((dir.y - _HeightStart) / (_HeightStop - _HeightStart));

                return lerp(_ColorBottom, _ColorTop, t);
            }
            ENDCG
        }
    }
}
