import{ar as e}from"./QueenComb-C90itEMJ.js";import{b as t,a as o,c as a,i as c,d,e as s,f as l,g as f}from"./clipPlaneVertex-BxS2rdGs.js";import{f as S,a as x,v as u}from"./vertexColorMixing-CxZU5RSI.js";import"./index-C6qSoOuU.js";import"./react-BikoVsHo.js";import"./motion-DmZWFm6O.js";import"./router-CAi4bOxy.js";import"./queenRepositoryWorld-DQIYnztg.js";const n="colorVertexShader",r=`attribute position: vec3f;
#ifdef VERTEXCOLOR
attribute color: vec4f;
#endif
#include<bonesDeclaration>
#include<bakedVertexAnimationDeclaration>
#include<clipPlaneVertexDeclaration>
#include<fogVertexDeclaration>
#ifdef FOG
uniform view: mat4x4f;
#endif
#include<instancesDeclaration>
uniform viewProjection: mat4x4f;
#if defined(VERTEXCOLOR) || defined(INSTANCESCOLOR) && defined(INSTANCES)
varying vColor: vec4f;
#endif
#define CUSTOM_VERTEX_DEFINITIONS
@vertex
fn main(input : VertexInputs)->FragmentInputs {
#define CUSTOM_VERTEX_MAIN_BEGIN
#ifdef VERTEXCOLOR
var colorUpdated: vec4f=vertexInputs.color;
#endif
#include<instancesVertex>
#include<bonesVertex>
#include<bakedVertexAnimation>
var worldPos: vec4f=finalWorld* vec4f(vertexInputs.position,1.0);vertexOutputs.position=uniforms.viewProjection*worldPos;
#include<clipPlaneVertex>
#include<fogVertex>
#include<vertexColorMixing>
#define CUSTOM_VERTEX_MAIN_END
}`;e.ShadersStoreWGSL[n]||(e.ShadersStoreWGSL[n]=r);const m=[t,o,a,S,c,d,s,l,f,x,u];for(const i of m)e.IncludesShadersStoreWGSL[i.name]||(e.IncludesShadersStoreWGSL[i.name]=i.shader);const O={name:n,shader:r};export{O as colorVertexShaderWGSL};
