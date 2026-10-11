import{a$ as e}from"./QueenComb-Cd0IuFn3.js";import{h as n}from"./helperFunctions-BH9NhuE9.js";import"./index-DnJy9pD2.js";import"./react--6nd5XBq.js";import"./motion-CvAcPNoJ.js";import"./router-CmS70aoX.js";const t="rgbdDecodePixelShader",a=`varying vUV: vec2f;var textureSamplerSampler: sampler;var textureSampler: texture_2d<f32>;
#include<helperFunctions>
#define CUSTOM_FRAGMENT_DEFINITIONS
@fragment
fn main(input: FragmentInputs)->FragmentOutputs {fragmentOutputs.color=vec4f(fromRGBD(textureSample(textureSampler,textureSamplerSampler,input.vUV)),1.0);}`;e.ShadersStoreWGSL[t]||(e.ShadersStoreWGSL[t]=a);const o=[n];for(const r of o)e.IncludesShadersStoreWGSL[r.name]||(e.IncludesShadersStoreWGSL[r.name]=r.shader);const u={name:t,shader:a};export{u as rgbdDecodePixelShaderWGSL};
