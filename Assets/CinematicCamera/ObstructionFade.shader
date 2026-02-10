// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

Shader "Custom/OverlayFade_BlockingOnly_Fixed"
{
    Properties
    {
        _FocusPoint ("Focus Point (World)", Vector) = (0,0,0,1)
        _FadeRadius ("Inner Fade Radius", Float) = 0.15
        _FadeFalloff ("Outer Fade Radius", Float) = 0.4
        _MaxFade ("Max Fade Amount", Float) = 1.0
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent+50"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
        }

        // IMPORTANT: These prevent black overlay
        Blend OneMinusDstAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            float4 _FocusPoint;
            float _FadeRadius;
            float _FadeFalloff;
            float _MaxFade;

            // float3 _WorldSpaceCameraPos;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float fragAlpha(float3 wpos)
            {
                float3 cam = _WorldSpaceCameraPos;
                float3 focus = _FocusPoint.xyz;

                float3 ray = focus - cam;
                float rayLen = length(ray);

                float3 camToP = wpos - cam;
                float t = dot(camToP, ray) / (rayLen * rayLen);

                // Fade only when the point is between camera & focus
                if (t < 0 || t > 1)
                    return 0.0;

                float3 closest = cam + ray * t;
                float dist = distance(wpos, closest);

                if (dist < _FadeRadius)
                    return _MaxFade;

                if (dist < _FadeFalloff)
                {
                    float lerpVal = 1 - ((dist - _FadeRadius) / (_FadeFalloff - _FadeRadius));
                    return lerpVal * _MaxFade;
                }

                return 0.0;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float a = fragAlpha(i.worldPos);

                // RGB is set to 1 so Unity does NOT treat this as black overlay
                return fixed4(1, 1, 1, a);
            }

            ENDCG
        }
    }
}
