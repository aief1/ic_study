class ahb_env;
ahb_agent agent;
ahb_ref_model ref_model;
ahb_scorbard scb;

mailbox #(ahb_transaction) req_mbx;
mailbox #(ahb_transaction) act_mbx;
mailbox #(ahb_transaction) exp_mbx;

function new(
    virtual AHB_SRAMC_IF.drv drv_vif,
    virtual AHB_SRAMC_IF.mon mon_vif
);

act_mbx = new();
exp_mbx = new();

agent = new(drv_vif, mon_vif, act_mbx, req_mbx);
ref_model = new(req_mbx, exp_mbx);
scb = new(act_mbx, exp_mbx);
endfunction

task run();
fork
    agent.run();
    ref_model.run();
    scb.run();

join_none
endtask
endclass

