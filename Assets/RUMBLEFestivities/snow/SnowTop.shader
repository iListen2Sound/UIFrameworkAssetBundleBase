Shader "Custom/URP/SnowTop_VerticalAndCutoffDisplaced"
{
    Properties
    {
        _SnowColor ("Snow Color", Color) = (1,1,1,1)
        _SnowStrength ("Snow Coverage (also slope cutoff)", Range(0,1)) = 0.6

        _NoiseScale ("Visual Noise Scale", Float) = 3
        _NoiseStrength ("Visual Noise Strength", Range(0,1)) = 0.35

        _NormalStrength ("Normal Perturb Strength", Range(0,1)) = 0.3

        _VerticalDisplacementStrength ("Vertical Displacement Strength", Range(0,1)) = 0.05
        _VerticalDisplacementNoiseScale ("Vertical Noise Scale", Float) = 2

        _CutoffPushStrength ("Cutoff Push Strength", Range(0,1)) = 0.1
        _CutoffPushWidth ("Cutoff Push Width", Range(0,0.2)) = 0.05

        _SparkleStrength ("Sparkle Strength", Range(0,2)) = 0.8
        _SparkleThreshold ("Sparkle Threshold", Range(0.7,0.99)) = 0.9
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "Queue"="AlphaTest"
            "RenderType"="TransparentCutout"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }

            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float3 positionOS : TEXCOORD2;
                float3 viewDirWS  : TEXCOORD3;
                float slope       : TEXCOORD4;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _SnowColor;
                float _SnowStrength;
                float _NoiseScale;
                float _NoiseStrength;
                float _NormalStrength;
                float _VerticalDisplacementStrength;
                float _VerticalDisplacementNoiseScale;
                float _CutoffPushStrength;
                float _CutoffPushWidth;
                float _SparkleStrength;
                float _SparkleThreshold;
            CBUFFER_END

            // ------------------------------------------------------------
            // Hash & Value Noise
            // ------------------------------------------------------------

            float hash(float3 p)
            {
                p = frac(p * 0.3183099 + 0.1);
                p *= 17.0;
                return frac(p.x * p.y * p.z * (p.x + p.y + p.z));
            }

            float noise(float3 p)
            {
                float3 i = floor(p);
                float3 f = frac(p);
                f = f * f * (3.0 - 2.0 * f);

                float n000 = hash(i + float3(0,0,0));
                float n100 = hash(i + float3(1,0,0));
                float n010 = hash(i + float3(0,1,0));
                float n110 = hash(i + float3(1,1,0));
                float n001 = hash(i + float3(0,0,1));
                float n101 = hash(i + float3(1,0,1));
                float n011 = hash(i + float3(0,1,1));
                float n111 = hash(i + float3(1,1,1));

                float n00 = lerp(n000, n100, f.x);
                float n10 = lerp(n010, n110, f.x);
                float n01 = lerp(n001, n101, f.x);
                float n11 = lerp(n011, n111, f.x);

                float n0 = lerp(n00, n10, f.y);
                float n1 = lerp(n01, n11, f.y);

                return lerp(n0, n1, f.z);
            }

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                float3 posOS = IN.positionOS.xyz;
                float3 normalWS = normalize(TransformObjectToWorldNormal(IN.normalOS));
                float3 worldUp = float3(0,1,0);

                // -------------------------------
                // Slope factor controlled by SnowStrength
                // -------------------------------
                float slope = dot(normalWS, worldUp);
                float slopeMask = step(_SnowStrength, slope);

                // -------------------------------
                // Vertical displacement (world Y only)
                // -------------------------------
                float3 worldPos = TransformObjectToWorld(posOS);
                float3 dispNoisePos = worldPos * _VerticalDisplacementNoiseScale;
                float dn = noise(dispNoisePos);

                posOS.y += dn * _VerticalDisplacementStrength * slope * slopeMask;

                // -------------------------------
                // Normal-based inward push near cutoff
                // -------------------------------
                float cutoffBand = smoothstep(_SnowStrength, _SnowStrength + _CutoffPushWidth, slope);
                float pushFactor = 1.0 - cutoffBand; // stronger near cutoff
                posOS -= IN.normalOS * (_CutoffPushStrength * pushFactor);

                OUT.positionOS = posOS;
                OUT.positionWS = TransformObjectToWorld(posOS);
                OUT.positionCS = TransformWorldToHClip(OUT.positionWS);
                OUT.normalWS = normalWS;
                OUT.viewDirWS = GetWorldSpaceViewDir(OUT.positionWS);
                OUT.slope = slope;
                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                float3 normalWS = normalize(IN.normalWS);

                // -------------------------------
                // Hard cutoff: discard steep surfaces
                // -------------------------------
                clip(IN.slope - _SnowStrength);

                // -------------------------------
                // Visual noise mask
                // -------------------------------
                float3 noisePos = IN.positionOS * _NoiseScale;
                float n = noise(noisePos);
                float snowMask = lerp(1.0, n, _NoiseStrength);
                snowMask *= _SnowStrength;

                // -------------------------------
                // Normal perturbation
                // -------------------------------
                float eps = 0.1;
                float nx = noise(noisePos + float3(eps,0,0));
                float ny = noise(noisePos + float3(0,eps,0));
                float nz = noise(noisePos + float3(0,0,eps));

                float3 perturbedNormal = normalize(
                    normalWS +
                    float3(nx - n, ny - n, nz - n) * (_NormalStrength * 2.0)
                );

                // -------------------------------
                // Lighting
                // -------------------------------
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(perturbedNormal, mainLight.direction));
                float lighting = lerp(0.65, 1.0, NdotL);

                // -------------------------------
                // Sparkles
                // -------------------------------
                float3 viewDir = normalize(IN.viewDirWS);
                float sparkle = pow(
                    saturate(dot(reflect(-mainLight.direction, perturbedNormal), viewDir)),
                    64
                );

                sparkle *= step(_SparkleThreshold, n);
                sparkle *= _SparkleStrength;

                float3 color =
                    _SnowColor.rgb * lighting +
                    sparkle * mainLight.color;

                return float4(color, 1.0); // opaque
            }
            ENDHLSL
        }
    }
}
