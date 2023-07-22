module pred
#(
    parameter BTBNUM = 32,
	parameter RASNUM = 16,
    parameter BTBGRPSIZE = 2,
    parameter BTBGRPNUM = BTBNUM / BTBGRPSIZE
)
(
    input             clk           ,
    input             reset         ,
    //from/to if
    input  [31:0]     fetch_pc      ,//要预测的pc
    output [31:0]     ret_pc        ,//方向预测
    output            taken         ,//分支预测
    output            ret_en        ,//方向预测命中可用

    //update btb
    input             branch_mistaken  ,//更新跳转目标使能
    input  [31:0]     wrong_pc         ,//跳转指令PC
    input  [31:0]     right_target     ,//正确的跳转目�?
    input             ins_type         ,
    
    input             retire_pc        ,
    input             right_orien   //分支预测正确与否

);
endmodule
