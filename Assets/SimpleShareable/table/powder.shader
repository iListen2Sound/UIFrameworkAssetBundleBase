Shader "Custom/URP/ShinyPowder"
{
    Properties
    {
        _BaseColor("Base Color", Color) = (0.9, 0.9, 0.9, 1)
        _Metallic("Metallic", Range(0, 1)) = 0.9
        _BaseRoughness("Base Roughness", Range(0, 1)) = 0.2
        _RoughnessVariation("Roughness Variation", Range(0, 1)) = 0.3
        _VoronoiScale("Voronoi Scale", Float) = 20.0
        
        [Header(Glints)]
        _GlintDensity("Glint Density", Range(10, 500)) = 100.0
        _GlintSize("Glint Size", Range(0.01, 0.5)) = 0.1
        _GlintThreshold("Glint Coverage", Range(0, 1)) = 0.3
        _GlintStrength("Glint Strength", Range(0, 10)) = 3.0
        _GlintColor("Glint Color", Color) = (1, 1, 1, 1)
        _GlintSharpness("Glint Sharpness", Range(10, 200)) = 80.0
        _ViewSensitivity("View Angle Sensitivity", Range(0, 1)) = 0.5
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float _Metallic;
                float _BaseRoughness;
                float _RoughnessVariation;
                float _VoronoiScale;
                float _GlintDensity;
                float _GlintSize;
                float _GlintThreshold;
                float _GlintStrength;
                float4 _GlintColor;
                float _GlintSharpness;
                float _ViewSensitivity;
            CBUFFER_END
            
            float3 hash3(float3 p)
            {
                p = float3(dot(p, float3(127.1, 311.7, 74.7)),
                          dot(p, float3(269.5, 183.3, 246.1)),
                          dot(p, float3(113.5, 271.9, 124.6)));
                return frac(sin(p) * 43758.5453123);
            }
            
            float2 voronoi(float3 x, float scale)
            {
                x *= scale;
                float3 p = floor(x);
                float3 f = frac(x);
                
                float minDist = 1.0;
                float secondMinDist = 1.0;
                
                for(int k = -1; k <= 1; k++)
                {
                    for(int j = -1; j <= 1; j++)
                    {
                        for(int i = -1; i <= 1; i++)
                        {
                            float3 neighbor = float3(float(i), float(j), float(k));
                            float3 cellPoint = hash3(p + neighbor);
                            float3 diff = neighbor + cellPoint - f;
                            float dist = length(diff);
                            
                            if(dist < minDist)
                            {
                                secondMinDist = minDist;
                                minDist = dist;
                            }
                            else if(dist < secondMinDist)
                            {
                                secondMinDist = dist;
                            }
                        }
                    }
                }
                
                return float2(minDist, secondMinDist - minDist);
            }
            
            float calculateGlints(float3 worldPos, float3 normal, float3 viewDir, float3 lightDir)
            {
                // Scale world position by density
                float3 scaledPos = worldPos * _GlintDensity;
                float3 cellPos = floor(scaledPos);
                float3 localPos = frac(scaledPos);
                
                float totalGlint = 0.0;
                
                // Check current and neighboring cells
                for(int k = -1; k <= 1; k++)
                {
                    for(int j = -1; j <= 1; j++)
                    {
                        for(int i = -1; i <= 1; i++)
                        {
                            float3 cellOffset = float3(i, j, k);
                            float3 neighborCell = cellPos + cellOffset;
                            
                            // Generate stable random values for this cell
                            float3 cellRandom = hash3(neighborCell);
                            
                            // Decide if this cell has a glint based on threshold only
                            if(cellRandom.x > _GlintThreshold)
                            {
                                // Position of glint within the cell
                                float3 glintLocalPos = cellRandom;
                                float3 cellWorldPos = neighborCell + glintLocalPos;
                                
                                // Distance from current position to glint center (in cell space)
                                float3 toGlint = scaledPos - cellWorldPos;
                                float distToGlint = length(toGlint);
                                
                                // Check if we're within the glint radius
                                if(distToGlint < _GlintSize)
                                {
                                    // Smooth falloff from glint center
                                    float coverage = 1.0 - smoothstep(_GlintSize * 0.5, _GlintSize, distToGlint);
                                    
                                    // Use second random component for intensity variation
                                    float intensity = lerp(0.5, 1.0, cellRandom.y);
                                    
                                    totalGlint += coverage * intensity;
                                }
                            }
                        }
                    }
                }
                
                return saturate(totalGlint);
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;
                output.normalWS = normalInput.normalWS;
                output.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);
                
                return output;
            }
            
            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                float3 normalWS = normalize(input.normalWS);
                float3 viewDirWS = normalize(input.viewDirWS);
                
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                float3 lightDir = mainLight.direction;
                
                float2 voronoiResult = voronoi(input.positionWS, _VoronoiScale);
                float roughnessVariation = voronoiResult.y;
                float finalRoughness = saturate(_BaseRoughness + roughnessVariation * _RoughnessVariation);
                float smoothness = 1.0 - finalRoughness;
                
                float glints = calculateGlints(input.positionWS, normalWS, viewDirWS, lightDir);
                
                InputData lightingInput = (InputData)0;
                lightingInput.positionWS = input.positionWS;
                lightingInput.normalWS = normalWS;
                lightingInput.viewDirectionWS = viewDirWS;
                lightingInput.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                lightingInput.bakedGI = half3(0, 0, 0);
                
                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = _BaseColor.rgb;
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = smoothness;
                surfaceData.normalTS = float3(0, 0, 1);
                surfaceData.occlusion = 1.0;
                surfaceData.alpha = 1.0;
                surfaceData.emission = 0;
                surfaceData.specular = 0;
                
                half4 color = UniversalFragmentPBR(lightingInput, surfaceData);
                color.rgb += glints * _GlintStrength * _GlintColor.rgb * mainLight.color;
                
                return color;
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}