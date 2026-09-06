import{r as s,j as e,F as x}from"./react-BikoVsHo.js";import{u as T,a as j}from"./index-BsYbMlbQ.js";import{L as h}from"./router-DHWxIZD9.js";import"./motion-DmZWFm6O.js";const y={en:{compiler:"Trinity HLS Compiler",source:"Source",target:"Target",lexical:"Lexical analysis",parsing:"Parsing AST",semantic:"Semantic analysis",optimization:"SU(3) optimization",scheduling:"Golden ratio scheduling",resources:"Resource allocation",complete:"Compilation complete",starting:"Starting compilation...",playground:"PLAYGROUND",run:"Run",compiling:"Compiling...",back:"Back",sourcePanel:"SOURCE",compilerLogs:"COMPILER LOGS",hardwareOutput:"HARDWARE OUTPUT",line:"Ln",encoding:"UTF-8",metaTitle:"Compiler playground",metaDescription:"An interactive Trinity HLS compiler playground for source-to-hardware examples."},ru:{compiler:"Компилятор Trinity HLS",source:"Источник",target:"Цель",lexical:"Лексический анализ",parsing:"Разбор AST",semantic:"Семантический анализ",optimization:"Оптимизация SU(3)",scheduling:"Планирование по золотому сечению",resources:"Распределение ресурсов",complete:"Компиляция завершена",starting:"Запуск компиляции…",playground:"ПЕСОЧНИЦА",run:"Запустить",compiling:"Компиляция…",back:"Назад",sourcePanel:"ИСХОДНЫЙ КОД",compilerLogs:"ЛОГИ КОМПИЛЯТОРА",hardwareOutput:"ВЫВОД ДЛЯ ЖЕЛЕЗА",line:"Строка",encoding:"UTF-8",metaTitle:"Песочница компилятора",metaDescription:"Интерактивная песочница Trinity HLS для примеров преобразования исходного кода в аппаратный код."}},C=[{id:"vibee",name:"VIBEE (.999)",icon:"🔺"},{id:"python",name:"Python",icon:"🐍"},{id:"rust",name:"Rust",icon:"🦀"},{id:"zig",name:"Zig",icon:"⚡"},{id:"cpp",name:"C++",icon:"⚙️"}],R=[{id:"verilog",name:"Verilog",icon:"📟"},{id:"systemverilog",name:"SystemVerilog",icon:"SV"},{id:"vhdl",name:"VHDL",icon:"📼"}],S={vibee:`// TRINITY NATIVE - Hardware Acceleration
// Target: Trinity Core V5.0

module quantum_kernel {
    const PHI = 1.6180339887;
    const TRINITY = 27;
    
    pub fn golden_transform(x: i64) -> i64 {
        return x * PHI + x / PHI;
    }
    
    pub fn main() {
        let result = golden_transform(TRINITY);
        print("φ² + 1/φ² = ", result);
    }
}`,python:`# Python → Hardware Acceleration
import trinity

@trinity.accelerate(target="verilog")
def matrix_multiply(A, B):
    n = len(A)
    C = [[0] * n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            for k in range(n):
                C[i][j] += A[i][k] * B[k][j]
    return C

if __name__ == "__main__":
    result = matrix_multiply([[1,2],[3,4]], [[5,6],[7,8]])
    print(f"Result: {result}")`,rust:`// Rust → Hardware Synthesis
#[trinity::accelerate]
fn fibonacci_hw(n: u32) -> u64 {
    if n <= 1 { return n as u64; }
    let mut a: u64 = 0;
    let mut b: u64 = 1;
    for _ in 2..=n {
        let temp = a + b;
        a = b;
        b = temp;
    }
    b
}

fn main() {
    let result = fibonacci_hw(42);
    println!("Fib(42) = {}", result);
}`,zig:`// Zig → Trinity Native
const std = @import("std");
const PHI: f64 = 1.6180339887498948;

pub fn goldenRatio(x: f64) f64 {
    return x * PHI + x / PHI;
}

pub fn main() !void {
    const result = goldenRatio(27.0);
    std.debug.print("Result: {d:.6}\\n", .{result});
}`,cpp:`// C++ → Hardware Synthesis
#include <trinity/hls.hpp>

#pragma trinity accelerate
template<size_t N>
void parallel_sum(int input[N], int output[N]) {
    output[0] = input[0];
    for (size_t i = 1; i < N; ++i) {
        output[i] = output[i-1] + input[i];
    }
}

int main() {
    int data[8] = {1, 2, 3, 4, 5, 6, 7, 8};
    int result[8];
    parallel_sum<8>(data, result);
    return 0;
}`};function w(l,i,o,n,r){const d=new Date().toISOString(),a=l.split(`
`).length,p=[`[${d}] ${n.compiler} V5.0`,`[INFO] ${n.source}: ${i.toUpperCase()} (${a} ${r?"строк":"lines"})`,`[INFO] ${n.target}: ${o.toUpperCase()}`,`[PASS] ${n.lexical}... OK`,`[PASS] ${n.parsing}... ${Math.floor(a*1.5)} ${r?"узлов":"nodes"}`,`[PASS] ${n.semantic}... OK`,`[PASS] ${n.optimization}... ${r?"применено шаблонов: 12":"12 patterns applied"}`,`[PASS] ${n.scheduling} (φ = 1.618)`,`[PASS] ${n.resources}: 3 DSPs, 12 BRAMs`,`[SUCCESS] ${n.complete}`];let c="";return o==="verilog"||o==="systemverilog"?c=`// TRINITY HLS V5.0 - Generated ${o.toUpperCase()}
// Source: ${i} | ${d}

\`timescale 1ns / 1ps

module trinity_accelerator #(
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   valid_in,
    input  wire [DATA_WIDTH-1:0]  data_in,
    output reg                    valid_out,
    output reg  [DATA_WIDTH-1:0]  data_out
);

    // Sacred Constants
    localparam [31:0] PHI = 32'h19E3779B;
    
    // Pipeline
    reg [DATA_WIDTH-1:0] stage1, stage2;
    reg [1:0] valid_pipe;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage1 <= 0;
            stage2 <= 0;
            valid_pipe <= 0;
            valid_out <= 0;
            data_out <= 0;
        end else begin
            // Stage 1: Transform
            stage1 <= (data_in * PHI) >> 16;
            valid_pipe[0] <= valid_in;
            
            // Stage 2: Output
            stage2 <= stage1;
            valid_pipe[1] <= valid_pipe[0];
            
            data_out <= stage2;
            valid_out <= valid_pipe[1];
        end
    end

endmodule`:c=`-- TRINITY HLS V5.0 - Generated VHDL
-- Source: ${i} | ${d}

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trinity_accelerator is
    port (
        clk       : in  std_logic;
        rst_n     : in  std_logic;
        valid_in  : in  std_logic;
        data_in   : in  std_logic_vector(31 downto 0);
        valid_out : out std_logic;
        data_out  : out std_logic_vector(31 downto 0)
    );
end entity;

architecture RTL of trinity_accelerator is
    constant PHI : unsigned(31 downto 0) := x"19E3779B";
    signal stage1, stage2 : unsigned(31 downto 0);
begin
    process(clk, rst_n) begin
        if rst_n = '0' then
            stage1 <= (others => '0');
            data_out <= (others => '0');
        elsif rising_edge(clk) then
            stage1 <= resize(unsigned(data_in) * PHI, 32);
            data_out <= std_logic_vector(stage1);
        end if;
    end process;
end RTL;`,{output:c,logs:p}}const b=l=>({vibee:"rust",python:"python",rust:"rust",zig:"c",cpp:"cpp",verilog:"systemverilog",systemverilog:"systemverilog",vhdl:"vhdl"})[l]||"plaintext";function P(){const{lang:l}=T(),i=l==="ru"?y.ru:y.en,[o,n]=s.useState("vibee"),[r,d]=s.useState("verilog"),[a,p]=s.useState(S.vibee),[c,_]=s.useState(""),[v,g]=s.useState([]),[u,m]=s.useState(!1);j(i.metaTitle,i.metaDescription);const f=s.useCallback(()=>{m(!0),g([`[INFO] ${i.starting}`]),setTimeout(()=>{const t=w(a,o,r,i,l==="ru");_(t.output),g(t.logs),m(!1)},400)},[a,o,r,i]);return s.useEffect(()=>{p(S[o]||"// Enter code...")},[o]),s.useEffect(()=>{f()},[]),e.jsxs("div",{style:{display:"flex",flexDirection:"column",height:"100dvh",background:"#0d1117",color:"#c9d1d9",fontFamily:"'JetBrains Mono', monospace"},children:[e.jsxs("header",{style:{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"0 16px",height:"48px",background:"#161b22",borderBottom:"1px solid #30363d"},children:[e.jsxs(h,{to:"/",style:{display:"flex",alignItems:"center",gap:8,textDecoration:"none",minWidth:0,flexShrink:1,overflow:"hidden"},children:[e.jsx("span",{style:{fontSize:24,flexShrink:0},children:"🔺"}),e.jsx("span",{style:{fontSize:16,fontWeight:700,color:"#fff",whiteSpace:"nowrap"},children:"TRINITY"}),e.jsx("span",{style:{fontSize:10,color:"#8b949e",background:"#21262d",padding:"2px 6px",borderRadius:3,whiteSpace:"nowrap",overflow:"hidden",textOverflow:"ellipsis"},children:i.playground})]}),e.jsxs("div",{style:{display:"flex",gap:8,flexShrink:0},children:[e.jsxs("button",{onClick:f,disabled:u,style:{display:"flex",alignItems:"center",gap:6,background:"#238636",color:"#fff",border:"none",borderRadius:6,padding:"6px 14px",fontSize:13,fontWeight:600,cursor:"pointer"},children:["▶ ",u?i.compiling:i.run]}),e.jsx(h,{to:"/",style:{background:"transparent",color:"#8b949e",border:"1px solid #30363d",borderRadius:6,padding:"5px 12px",fontSize:12,textDecoration:"none"},children:`← ${i.back}`})]})]}),e.jsxs("main",{style:{display:"flex",flex:1,overflow:"hidden",flexWrap:"wrap"},children:[e.jsxs("div",{style:{flex:"1 1 300px",minWidth:0,display:"flex",flexDirection:"column",borderRight:"1px solid #30363d"},children:[e.jsxs("div",{style:{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"8px 12px",background:"#161b22",borderBottom:"1px solid #30363d"},children:[e.jsxs("span",{style:{fontSize:11,fontWeight:600,color:"#58a6ff"},children:["📝 ",i.sourcePanel]}),e.jsx("select",{value:o,onChange:t=>n(t.target.value),style:{background:"#21262d",color:"#c9d1d9",border:"1px solid #30363d",borderRadius:4,padding:"2px 6px",fontSize:11},children:C.map(t=>e.jsxs("option",{value:t.id,children:[t.icon," ",t.name]},t.id))})]}),e.jsx("div",{style:{flex:1},children:e.jsx(x,{height:"100%",language:b(o),theme:"vs-dark",value:a,onChange:t=>p(t||""),options:{fontSize:13,minimap:{enabled:!1},scrollBeyondLastLine:!1,padding:{top:12}}})})]}),e.jsxs("div",{style:{flex:"1 1 280px",maxWidth:400,minWidth:0,display:"flex",flexDirection:"column",background:"#0d1117",borderRight:"1px solid #30363d"},children:[e.jsx("div",{style:{padding:"8px 12px",background:"#161b22",borderBottom:"1px solid #30363d"},children:e.jsxs("span",{style:{fontSize:11,fontWeight:600,color:"#f0883e"},children:["📋 ",i.compilerLogs]})}),e.jsx("div",{style:{flex:1,overflow:"auto",padding:12,fontSize:11,lineHeight:1.8},children:u?e.jsxs("div",{style:{color:"#58a6ff"},children:["⏳ ",i.compiling]}):v.map((t,I)=>e.jsx("div",{style:{color:t.includes("[SUCCESS]")?"#7ee787":t.includes("[ERROR]")?"#f85149":t.includes("[PASS]")?"#58a6ff":t.includes("[INFO]")?"#8b949e":"#c9d1d9",borderBottom:"1px solid #21262d",paddingBottom:4,marginBottom:4},children:t},I))})]}),e.jsxs("div",{style:{flex:"1 1 300px",minWidth:0,display:"flex",flexDirection:"column"},children:[e.jsxs("div",{style:{display:"flex",alignItems:"center",justifyContent:"space-between",padding:"8px 12px",background:"#161b22",borderBottom:"1px solid #30363d"},children:[e.jsxs("span",{style:{fontSize:11,fontWeight:600,color:"#7ee787"},children:["🔧 ",i.hardwareOutput]}),e.jsx("select",{value:r,onChange:t=>{d(t.target.value)},style:{background:"#21262d",color:"#c9d1d9",border:"1px solid #30363d",borderRadius:4,padding:"2px 6px",fontSize:11},children:R.map(t=>e.jsxs("option",{value:t.id,children:[t.icon," ",t.name]},t.id))})]}),e.jsx("div",{style:{flex:1},children:e.jsx(x,{height:"100%",language:b(r),theme:"vs-dark",value:c,options:{fontSize:13,minimap:{enabled:!1},scrollBeyondLastLine:!1,padding:{top:12},readOnly:!0}})})]})]}),e.jsxs("footer",{style:{display:"flex",justifyContent:"space-between",padding:"0 16px",height:24,background:"#238636",color:"#fff",fontSize:11,alignItems:"center"},children:[e.jsxs("span",{children:[i.line," ",a.split(`
`).length," | ",i.encoding]}),e.jsx("span",{children:"VIBEE v0.9.99 | Trinity Core v5.0 | φ² + 1/φ² = 3"})]})]})}export{P as default};
