class ahb_agent;

  ahb_driver drv;
  ahb_monitor mon;

  function new(
        virtual AHB_SRAMC_IF.drv  drv_vif,
        virtual AHB_SRAMC_IF.mon  mon_vif,
        mailbox #(ahb_transaction) mon_mbx
  );
  drv = new(drv_vif);
  mon = new(mon_vif, mon_mbx);
  endfunction

   task run();
    fork
    mon.run();
    join_none
   endtask
  endclass