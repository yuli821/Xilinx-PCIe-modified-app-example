
//-----------------------------------------------------------------------------
//
// (c) Copyright 2017-2019 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
//
// Project    : Versal PCI Express Integrated Block
// File       : xilinx_pcie_versal_ep.v
// Version    : 1.0 
//-----------------------------------------------------------------------------
//--
//-- Description:  PCI Express Endpoint example FPGA design
//--
//------------------------------------------------------------------------------
`define PCIE4_NEW_PINS 1
`timescale 1ps / 1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module xilinx_pcie_versal_ep # (
  parameter [4:0]    PL_LINK_CAP_MAX_LINK_WIDTH     = 4,  // 1- X1, 2 - X2, 4 - X4, 8 - X8, 16 - X16
  parameter          C_DATA_WIDTH                   = 128,         // RX/TX interface data width
  parameter          AXISTEN_IF_MC_RX_STRADDLE      = 0,
  parameter          PL_LINK_CAP_MAX_LINK_SPEED     = 4,  // 1- GEN1, 2 - GEN2, 4 - GEN3, 8 - GEN4
  parameter          KEEP_WIDTH                     = C_DATA_WIDTH / 32,
  parameter          EXT_PIPE_SIM                   = "FALSE",  // This Parameter has effect on selecting Enable External PIPE Interface in GUI.
  parameter          AXISTEN_IF_CC_ALIGNMENT_MODE   = "FALSE",
  parameter          AXISTEN_IF_CQ_ALIGNMENT_MODE   = "FALSE",
  parameter          AXISTEN_IF_RQ_ALIGNMENT_MODE   = "FALSE",
  parameter          AXISTEN_IF_RC_ALIGNMENT_MODE   = "FALSE",
  parameter          AXI4_CQ_TUSER_WIDTH            = 229,
  parameter          AXI4_CC_TUSER_WIDTH            = 81,
  parameter          AXI4_RC_TUSER_WIDTH            = 161,
  parameter          AXI4_RQ_TUSER_WIDTH            = 183,
  parameter          AXISTEN_IF_ENABLE_CLIENT_TAG   = 0,
  parameter          RQ_AVAIL_TAG_IDX               = 8,
  parameter          RQ_AVAIL_TAG                   = 256,
  parameter          AXISTEN_IF_RQ_PARITY_CHECK     = 0,
  parameter          AXISTEN_IF_CC_PARITY_CHECK     = 0,
  parameter          AXISTEN_IF_RC_PARITY_CHECK     = 0,
  parameter          AXISTEN_IF_CQ_PARITY_CHECK     = 0,
  parameter          AXISTEN_IF_ENABLE_RX_MSG_INTFC = 0,
  parameter   [17:0] AXISTEN_IF_ENABLE_MSG_ROUTE    = 18'h2FFFF,
  parameter          CCIX_ENABLE                    = "FALSE",
  parameter          AXIS_CCIX_RX_TDATA_WIDTH       = 256,
  parameter          AXIS_CCIX_TX_TDATA_WIDTH       = 256,
  parameter          AXIS_CCIX_RX_TUSER_WIDTH       = 47,
  parameter          AXIS_CCIX_TX_TUSER_WIDTH       = 47
) (
  output  [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txp,
  output  [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_txn,
  input   [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxp,
  input   [(PL_LINK_CAP_MAX_LINK_WIDTH - 1) : 0]  pci_exp_rxn,



  input  sys_rst_n,

  input sys_clk_p,
  input sys_clk_n
);
  // Local Parameters derived from user selection
  localparam TCQ = 1;

  wire  user_lnk_up;
  wire  phy_rdy_out;

  //----------------------------------------------------------------------------------------------------------------//
  //  AXI Interface                                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//

  wire  user_clk;
  wire  core_clk;
  wire  user_reset;

  wire                            s_axis_rq_tlast;
  wire        [C_DATA_WIDTH-1:0]  s_axis_rq_tdata;
  wire [AXI4_RQ_TUSER_WIDTH-1:0]  s_axis_rq_tuser;
  wire          [KEEP_WIDTH-1:0]  s_axis_rq_tkeep;
  wire                     [3:0]  s_axis_rq_tready;
  wire                            s_axis_rq_tvalid;

  wire        [C_DATA_WIDTH-1:0]  m_axis_rc_tdata;
  wire [AXI4_RC_TUSER_WIDTH-1:0]  m_axis_rc_tuser;
  wire                            m_axis_rc_tlast;
  wire          [KEEP_WIDTH-1:0]  m_axis_rc_tkeep;
  wire                            m_axis_rc_tvalid;
  wire                            m_axis_rc_tready;

  wire        [C_DATA_WIDTH-1:0]  m_axis_cq_tdata;
  wire [AXI4_CQ_TUSER_WIDTH-1:0]  m_axis_cq_tuser;
  wire                            m_axis_cq_tlast;
  wire          [KEEP_WIDTH-1:0]  m_axis_cq_tkeep;
  wire                            m_axis_cq_tvalid;
  wire                            m_axis_cq_tready;

  wire        [C_DATA_WIDTH-1:0]  s_axis_cc_tdata;
  wire [AXI4_CC_TUSER_WIDTH-1:0]  s_axis_cc_tuser;
  wire                            s_axis_cc_tlast;
  wire          [KEEP_WIDTH-1:0]  s_axis_cc_tkeep;
  wire                            s_axis_cc_tvalid;
  wire                     [3:0]  s_axis_cc_tready;

  wire                     [3:0]  pcie_tfc_nph_av;
  wire                     [3:0]  pcie_tfc_npd_av;
  //----------------------------------------------------------------------------------------------------------------//
  //  Configuration (CFG) Interface                                                                                 //
  //----------------------------------------------------------------------------------------------------------------//

  wire       pcie_cq_np_req;
  wire [5:0] pcie_cq_np_req_count;
  wire [5:0] pcie_rq_seq_num0;
  wire       pcie_rq_seq_num_vld0;
  wire [5:0] pcie_rq_seq_num1;
  wire       pcie_rq_seq_num_vld1;

  //----------------------------------------------------------------------------------------------------------------//
  // EP and RP                                                                                                      //
  //----------------------------------------------------------------------------------------------------------------//

  wire         cfg_phy_link_down;
  wire   [2:0] cfg_negotiated_width;
  wire   [2:0] cfg_current_speed;
  wire   [1:0] cfg_max_payload;
  wire   [2:0] cfg_max_read_req;
  wire  [15:0] cfg_function_status;
  wire  [11:0] cfg_function_power_state;
  wire [503:0] cfg_vf_status;
  wire [755:0] cfg_vf_power_state;
  wire   [1:0] cfg_link_power_state;

  // Error Reporting Interface
  wire  cfg_err_cor_out;
  wire  cfg_err_nonfatal_out;
  wire  cfg_err_fatal_out;

  wire   [5:0] cfg_ltssm_state;
  wire   [3:0] cfg_rcb_status;
  wire   [1:0] cfg_obff_enable;
  wire         cfg_pl_status_change;

  wire   [3:0] cfg_tph_requester_enable;
  wire  [11:0] cfg_tph_st_mode;
  wire [251:0] cfg_vf_tph_requester_enable;
  wire [755:0] cfg_vf_tph_st_mode;

  // Management Interface
  wire   [9:0] cfg_mgmt_addr;
  wire         cfg_mgmt_write;
  wire  [31:0] cfg_mgmt_write_data;
  wire   [3:0] cfg_mgmt_byte_enable;
  wire         cfg_mgmt_read;
  wire  [31:0] cfg_mgmt_read_data;
  wire         cfg_mgmt_read_write_done;
  wire         cfg_mgmt_type1_cfg_reg_access;
  wire         cfg_msg_received;
  wire   [7:0] cfg_msg_received_data;
  wire   [4:0] cfg_msg_received_type;
  wire         cfg_msg_transmit;
  wire   [2:0] cfg_msg_transmit_type;
  wire  [31:0] cfg_msg_transmit_data;
  wire         cfg_msg_transmit_done;

  wire   [7:0] cfg_fc_ph;
  wire  [11:0] cfg_fc_pd;
  wire   [7:0] cfg_fc_nph;
  wire  [11:0] cfg_fc_npd;
  wire   [7:0] cfg_fc_cplh;
  wire  [11:0] cfg_fc_cpld;
  wire   [2:0] cfg_fc_sel;

  wire  [63:0] cfg_dsn;
  wire         cfg_power_state_change_interrupt;
  wire         cfg_power_state_change_ack;
  wire         cfg_err_cor_in;
  wire         cfg_err_uncor_in;

  wire   [3:0] cfg_flr_in_process;
  wire   [3:0] cfg_flr_done;
  wire [251:0] cfg_vf_flr_in_process;
  wire         cfg_vf_flr_done;
  wire   [7:0] cfg_vf_flr_func_num;

  wire         cfg_link_training_enable;

  //----------------------------------------------------------------------------------------------------------------//
  // EP Only                                                                                                        //
  //----------------------------------------------------------------------------------------------------------------//

  // Interrupt Interface Signals
  wire    [3:0] cfg_interrupt_int;
  wire    [1:0] cfg_interrupt_pending;
  wire          cfg_interrupt_sent;

  wire   [31:0] cfg_interrupt_msi_int;
  wire    [7:0] cfg_interrupt_msi_function_number;
  wire    [2:0] cfg_interrupt_msi_attr;
  wire          cfg_interrupt_msi_tph_present;
  wire    [1:0] cfg_interrupt_msi_tph_type;
  wire    [7:0] cfg_interrupt_msi_tph_st_tag;
  wire          cfg_interrupt_msi_sent;
  wire          cfg_interrupt_msi_fail;

  wire   [31:0] cfg_interrupt_msi_data;
  wire    [3:0] cfg_interrupt_msi_enable;
  wire          cfg_interrupt_msi_mask_update;
  wire   [11:0] cfg_interrupt_msi_mmenable;
  wire   [63:0] cfg_interrupt_msi_pending_status;
  wire    [1:0] cfg_interrupt_msi_select;
  wire    [1:0] cfg_msi_pending_status_function_num;
  wire          cfg_msi_pending_status_data_enable;

  wire   [63:0] cfg_interrupt_msxi_address;
  wire   [31:0] cfg_interrupt_msxi_data;
  wire          cfg_interrupt_msix_int;
  wire    [1:0] cfg_interrupt_msix_vec_pending;
  wire          cfg_interrupt_msix_vec_pending_status;
  wire    [3:0] cfg_interrupt_msix_enable;
  wire    [3:0] cfg_interrupt_msix_mask;
  wire  [251:0] cfg_interrupt_msix_vf_mask;
  wire  [251:0] cfg_interrupt_msix_vf_enable;

  // EP only
  wire  cfg_hot_reset_out;
  wire  cfg_config_space_enable;
  wire  cfg_req_pm_transition_l23_ready;

  // RP only
  wire          cfg_hot_reset_in;

  wire [7:0]    cfg_ds_port_number;
  wire [7:0]    cfg_ds_bus_number;
  wire [4:0]    cfg_ds_device_number;


  //--------------------------------------------------------//
  //    System(SYS) Interface                               //
  //--------------------------------------------------------//

 

  wire  sys_clk;
  assign sys_clk = design_ep_i.bufg_gt_sysclk_BUFG_GT_O;
  wire  sys_rst_n_c;
  //-----------------------------------------------------------------------------------------------------------------------

  IBUF   sys_reset_n_ibuf (.O(sys_rst_n_c), .I(sys_rst_n));

  wire [15:0]  cfg_vend_id    = 16'h10EE;
  wire [15:0]  cfg_dev_id     = 16'hB034;
  wire [15:0]  cfg_dev_id_pf1 = 16'h9138;
  wire [15:0]  cfg_subsys_id  = 16'h0007;
  wire  [7:0]  cfg_rev_id     = 8'h00;
  wire [15:0]  cfg_subsys_vend_id = 16'h10EE;



//--------------------------------------------------------------------------//
//                         Support Level Wrapper                            //
//--------------------------------------------------------------------------//
  design_ep design_ep_i (
    //---------------------------------------------------------------------//
    //  ID Ports
    //---------------------------------------------------------------------//

    .pcie_cfg_mgmt_debug_access     (1'b0),
    .pcie_cfg_mgmt_function_number  (8'b0),

    .pcie_cfg_control_vf_flr_func_num(cfg_vf_flr_func_num),

    //------------------------------------------------------//
    //  USER_CLK; USER_RESET; USER_LINK_UP; PHY_RDY         //
    //------------------------------------------------------//
    .user_clk    (user_clk),
    .core_clk    (core_clk),
    .user_reset  (user_reset),
    .user_lnk_up (user_lnk_up),
    .phy_rdy_out (phy_rdy_out),

    //------------------------------------------------------//
    //  PCI Express (pci_exp) Interface                     //
    //------------------------------------------------------//
    // Tx
    .pcie_mgt_gtx_n (pci_exp_txn),
    .pcie_mgt_gtx_p (pci_exp_txp),

    // Rx
    .pcie_mgt_grx_n (pci_exp_rxn),
    .pcie_mgt_grx_p (pci_exp_rxp),

    //------------------------------------------------------//
    //  AXI Interface                                       //
    //------------------------------------------------------//
    .s_axis_rq_tlast  (s_axis_rq_tlast),
    .s_axis_rq_tdata  (s_axis_rq_tdata),
    .s_axis_rq_tuser  (s_axis_rq_tuser),
    .s_axis_rq_tkeep  (s_axis_rq_tkeep),
    .s_axis_rq_tready (s_axis_rq_tready),
    .s_axis_rq_tvalid (s_axis_rq_tvalid),

    .m_axis_rc_tdata  (m_axis_rc_tdata),
    .m_axis_rc_tuser  (m_axis_rc_tuser),
    .m_axis_rc_tlast  (m_axis_rc_tlast),
    .m_axis_rc_tkeep  (m_axis_rc_tkeep),
    .m_axis_rc_tvalid (m_axis_rc_tvalid),
    .m_axis_rc_tready (m_axis_rc_tready),

    .m_axis_cq_tdata  (m_axis_cq_tdata),
    .m_axis_cq_tuser  (m_axis_cq_tuser),
    .m_axis_cq_tlast  (m_axis_cq_tlast),
    .m_axis_cq_tkeep  (m_axis_cq_tkeep),
    .m_axis_cq_tvalid (m_axis_cq_tvalid),
    .m_axis_cq_tready (m_axis_cq_tready),

    .s_axis_cc_tdata  (s_axis_cc_tdata),
    .s_axis_cc_tuser  (s_axis_cc_tuser),
    .s_axis_cc_tlast  (s_axis_cc_tlast),
    .s_axis_cc_tkeep  (s_axis_cc_tkeep),
    .s_axis_cc_tvalid (s_axis_cc_tvalid),
    .s_axis_cc_tready (s_axis_cc_tready),

    //--------------------------------------------------------------//
    //  Configuration (CFG) Interface                               //
    //--------------------------------------------------------------//
    .pcie_cfg_status_rq_seq_num0 (pcie_rq_seq_num0) ,
    .pcie_cfg_status_rq_seq_num_vld0(pcie_rq_seq_num_vld0) ,
    .pcie_cfg_status_rq_seq_num1 (pcie_rq_seq_num1) ,
    .pcie_cfg_status_rq_seq_num_vld1(pcie_rq_seq_num_vld1) ,
    .pcie_cfg_status_rq_tag0     ( ),
    .pcie_cfg_status_rq_tag1     ( ),
    .pcie_cfg_status_rq_tag_av   ( ),
    .pcie_cfg_status_rq_tag_vld0 ( ),
    .pcie_cfg_status_rq_tag_vld1 ( ),

    .pcie_cfg_status_cq_np_req        ({1'b0,pcie_cq_np_req}),
    .pcie_cfg_status_cq_np_req_count  (pcie_cq_np_req_count),
    .pcie_cfg_status_phy_link_down    (cfg_phy_link_down),
    .pcie_cfg_status_phy_link_status  ( ),
    .pcie_cfg_status_negotiated_width (cfg_negotiated_width),
    .pcie_cfg_status_current_speed    (cfg_current_speed),
    .pcie_cfg_status_max_payload      (cfg_max_payload),
    .pcie_cfg_status_max_read_req     (cfg_max_read_req),
 
    .pcie_cfg_status_function_status  (cfg_function_status),
    .pcie_cfg_status_function_power_state(cfg_function_power_state),
    .pcie_cfg_status_rcb_status       (cfg_rcb_status),
    .pcie_cfg_status_vf_status        (cfg_vf_status),
    .pcie_cfg_status_vf_power_state   (cfg_vf_power_state),
    .pcie_cfg_status_link_power_state (cfg_link_power_state),
    .pcie_cfg_status_err_cor_out      (cfg_err_cor_out),
    .pcie_cfg_status_err_nonfatal_out (cfg_err_nonfatal_out),
    .pcie_cfg_status_err_fatal_out    (cfg_err_fatal_out),
    .pcie_cfg_status_local_error_out  ( ),
    .pcie_cfg_status_local_error_valid( ),
    .pcie_cfg_status_ltssm_state      (cfg_ltssm_state),
    .pcie_cfg_status_rx_pm_state      ( ),
    .pcie_cfg_status_tx_pm_state      ( ),
    .pcie_cfg_status_atomic_requester_enable ( ),
    .pcie_cfg_status_obff_enable      (cfg_obff_enable),
    .pcie_cfg_status_pl_status_change (cfg_pl_status_change),
    .pcie_cfg_status_tph_requester_enable(cfg_tph_requester_enable),
    .pcie_cfg_status_tph_st_mode      (cfg_tph_st_mode),
    .pcie_cfg_status_vf_tph_requester_enable(cfg_vf_tph_requester_enable),
    .pcie_cfg_status_vf_tph_st_mode   (cfg_vf_tph_st_mode),

    .pcie_cfg_mgmt_addr      (cfg_mgmt_addr),
    .pcie_cfg_mgmt_write_en  (cfg_mgmt_write),
    .pcie_cfg_mgmt_write_data(cfg_mgmt_write_data),
    .pcie_cfg_mgmt_byte_en   (cfg_mgmt_byte_enable),
    .pcie_cfg_mgmt_read_en   (cfg_mgmt_read),
    .pcie_cfg_mgmt_read_data (cfg_mgmt_read_data),
    .pcie_cfg_mgmt_read_write_done(cfg_mgmt_read_write_done),

    .pcie_cfg_mesg_rcvd_recd       (cfg_msg_received),
    .pcie_cfg_mesg_rcvd_recd_data  (cfg_msg_received_data),
    .pcie_cfg_mesg_rcvd_recd_type  (cfg_msg_received_type),
    .pcie_cfg_mesg_tx_transmit     (cfg_msg_transmit),
    .pcie_cfg_mesg_tx_transmit_type(cfg_msg_transmit_type),
    .pcie_cfg_mesg_tx_transmit_data(cfg_msg_transmit_data),
    .pcie_cfg_mesg_tx_transmit_done(cfg_msg_transmit_done),

    .pcie_cfg_fc_ph   (cfg_fc_ph),
    .pcie_cfg_fc_pd   (cfg_fc_pd),
    .pcie_cfg_fc_nph  (cfg_fc_nph),
    .pcie_cfg_fc_npd  (cfg_fc_npd),
    .pcie_cfg_fc_cplh (cfg_fc_cplh),
    .pcie_cfg_fc_cpld (cfg_fc_cpld),
    .pcie_cfg_fc_sel  (cfg_fc_sel),

    .pcie_transmit_fc_nph_av(pcie_tfc_nph_av),
    .pcie_transmit_fc_npd_av(pcie_tfc_npd_av),

    .pcie_cfg_control_bus_number            ( ),
    .pcie_cfg_control_dsn                   (cfg_dsn),
    .pcie_cfg_control_power_state_change_ack(cfg_power_state_change_ack),
    .pcie_cfg_control_power_state_change_interrupt (cfg_power_state_change_interrupt),
    .pcie_cfg_control_err_cor_in           (cfg_err_cor_in),
    .pcie_cfg_control_err_uncor_in         (cfg_err_uncor_in),
    .pcie_cfg_control_flr_in_process       (cfg_flr_in_process),
 
    .pcie_cfg_control_flr_done             (cfg_flr_done),
    .pcie_cfg_control_vf_flr_in_process    (cfg_vf_flr_in_process),
    .pcie_cfg_control_vf_flr_done          (cfg_vf_flr_done),
    .pcie_cfg_control_link_training_enable (cfg_link_training_enable),
    .pcie_cfg_control_hot_reset_out        (cfg_hot_reset_out),
    .pcie_cfg_control_config_space_enable  (cfg_config_space_enable),
    .pcie_cfg_control_req_pm_transition_l23_ready (cfg_req_pm_transition_l23_ready),
    .pcie_cfg_control_hot_reset_in         (cfg_hot_reset_in),
    .pcie_cfg_control_ds_bus_number        (cfg_ds_bus_number),
    .pcie_cfg_control_ds_device_number     (cfg_ds_device_number),
    .pcie_cfg_control_ds_port_number       (cfg_ds_port_number),

    .pcie_cfg_interrupt_intx_vector (cfg_interrupt_int),
    .pcie_cfg_interrupt_pending     ({2'b0,cfg_interrupt_pending}),
    .pcie_cfg_interrupt_sent        (cfg_interrupt_sent),

    // MSI Interface & MSI-X is not Internal
    .pcie_cfg_msi_attr       (cfg_interrupt_msi_attr),
    .pcie_cfg_msi_data       (cfg_interrupt_msi_data),
 
    .pcie_cfg_msi_function_number(cfg_interrupt_msi_function_number),
    .pcie_cfg_msi_enable     (cfg_interrupt_msi_enable),
    .pcie_cfg_msi_mmenable   (cfg_interrupt_msi_mmenable),
    .pcie_cfg_msi_int_vector (cfg_interrupt_msi_int),
    .pcie_cfg_msi_mask_update(cfg_interrupt_msi_mask_update),
    .pcie_cfg_msi_pending_status(cfg_interrupt_msi_pending_status [31:0]),
    .pcie_cfg_msi_select     (cfg_interrupt_msi_select),
    .pcie_cfg_msi_sent       ( ),
    .pcie_cfg_msi_fail       ( ),
    .pcie_cfg_msi_tph_present(cfg_interrupt_msi_tph_present),
    .pcie_cfg_msi_tph_st_tag (cfg_interrupt_msi_tph_st_tag),
    .pcie_cfg_msi_tph_type   (cfg_interrupt_msi_tph_type),
    .pcie_cfg_msi_pending_status_data_enable (1'b0),
    .pcie_cfg_msi_pending_status_function_num(2'b0),



    .pcie_cfg_control_pm_aspm_l1entry_reject       (1'b0),
    .pcie_cfg_control_pm_aspm_tx_l0s_entry_disable (1'b1),

    //--------------------------------------------//
    //  System(SYS) Interface                     //
    //--------------------------------------------//
    .pcie_refclk_clk_n  (sys_clk_n),
    .pcie_refclk_clk_p  (sys_clk_p),

    .sys_reset (sys_rst_n_c)
  );



//------------------------------------------------------------------------------------------------------------------//
//                                      PIO Example Design Top Level                                                //
//------------------------------------------------------------------------------------------------------------------//
  pcie_app_versal #(
    .AXI4_CQ_TUSER_WIDTH (AXI4_CQ_TUSER_WIDTH), 
    .AXI4_CC_TUSER_WIDTH (AXI4_CC_TUSER_WIDTH), 
    .AXI4_RC_TUSER_WIDTH (AXI4_RC_TUSER_WIDTH), 
    .AXI4_RQ_TUSER_WIDTH (AXI4_RQ_TUSER_WIDTH), 
    .C_DATA_WIDTH(C_DATA_WIDTH)
  ) pcie_app_versal_i (
    .user_clk    (user_clk),
    .user_reset  (user_reset),
    .user_lnk_up (user_lnk_up),
    .sys_rst     (sys_rst_n_c),

    //-------------------------------------------------------------------------------------//
    //  AXI Interface                                                                      //
    //-------------------------------------------------------------------------------------//
    .s_axis_rq_tlast  (s_axis_rq_tlast),
    .s_axis_rq_tdata  (s_axis_rq_tdata),
    .s_axis_rq_tuser  (s_axis_rq_tuser),
    .s_axis_rq_tkeep  (s_axis_rq_tkeep),
    .s_axis_rq_tready (s_axis_rq_tready[0]),
    .s_axis_rq_tvalid (s_axis_rq_tvalid),

    .m_axis_rc_tdata  (m_axis_rc_tdata),
    .m_axis_rc_tuser  (m_axis_rc_tuser),
    .m_axis_rc_tlast  (m_axis_rc_tlast),
    .m_axis_rc_tkeep  (m_axis_rc_tkeep),
    .m_axis_rc_tvalid (m_axis_rc_tvalid),
    .m_axis_rc_tready (m_axis_rc_tready),

    .m_axis_cq_tdata  (m_axis_cq_tdata),
    .m_axis_cq_tuser  (m_axis_cq_tuser),
    .m_axis_cq_tlast  (m_axis_cq_tlast),
    .m_axis_cq_tkeep  (m_axis_cq_tkeep),
    .m_axis_cq_tvalid (m_axis_cq_tvalid),
    .m_axis_cq_tready (m_axis_cq_tready),

    .s_axis_cc_tdata  (s_axis_cc_tdata),
    .s_axis_cc_tuser  (s_axis_cc_tuser),
    .s_axis_cc_tlast  (s_axis_cc_tlast),
    .s_axis_cc_tkeep  (s_axis_cc_tkeep),
    .s_axis_cc_tvalid (s_axis_cc_tvalid),
    .s_axis_cc_tready (s_axis_cc_tready[0]),

    .pcie_rq_seq_num      ('h0),
    .pcie_rq_seq_num_vld  ('h0),
    .pcie_rq_tag      ('h0),
    .pcie_rq_tag_vld  ('h0),
    .pcie_tfc_nph_av  (pcie_tfc_nph_av[1:0]),
    .pcie_tfc_npd_av  (pcie_tfc_npd_av[1:0]),
    .pcie_cq_np_req   (pcie_cq_np_req),
    .pcie_cq_np_req_count ( pcie_cq_np_req_count),

    //--------------------------------------------------------------------------------//
    //  Configuration (CFG) Interface                                                 //
    //--------------------------------------------------------------------------------//

    //--------------------------------------------------------------------------------//
    // EP and RP                                                                      //
    //--------------------------------------------------------------------------------//
    .cfg_phy_link_down        (cfg_phy_link_down),
    .cfg_negotiated_width     (cfg_negotiated_width),
    .cfg_current_speed        (cfg_current_speed),
    .cfg_max_payload          (cfg_max_payload),
    .cfg_max_read_req         (cfg_max_read_req),
    .cfg_function_status      (cfg_function_status [7:0]),
    .cfg_function_power_state (cfg_function_power_state [5:0]),
    .cfg_vf_status            (cfg_vf_status),
    //.cfg_vf_power_state     (cfg_vf_power_state),
    .cfg_link_power_state     (cfg_link_power_state),

    // Error Reporting Interface
    .cfg_err_cor_out      (cfg_err_cor_out),
    .cfg_err_nonfatal_out (cfg_err_nonfatal_out),
    .cfg_err_fatal_out    (cfg_err_fatal_out),
    .cfg_ltr_enable       (1'b0 ),
    .cfg_ltssm_state      (cfg_ltssm_state),
    .cfg_rcb_status       (cfg_rcb_status [1:0]),
    .cfg_obff_enable      (cfg_obff_enable),
    .cfg_pl_status_change (cfg_pl_status_change),

    // Management Interface
    .cfg_mgmt_addr            (cfg_mgmt_addr),
    .cfg_mgmt_write           (cfg_mgmt_write),
    .cfg_mgmt_write_data      (cfg_mgmt_write_data),
    .cfg_mgmt_byte_enable     (cfg_mgmt_byte_enable),
    .cfg_mgmt_read            (cfg_mgmt_read),
    .cfg_mgmt_read_data       (cfg_mgmt_read_data),
    .cfg_mgmt_read_write_done (cfg_mgmt_read_write_done),
    .cfg_mgmt_type1_cfg_reg_access (cfg_mgmt_type1_cfg_reg_access),
    .cfg_msg_received         (cfg_msg_received),
    .cfg_msg_received_data    (cfg_msg_received_data),
    .cfg_msg_received_type    (cfg_msg_received_type),
    .cfg_msg_transmit         (cfg_msg_transmit),
    .cfg_msg_transmit_type    (cfg_msg_transmit_type),
    .cfg_msg_transmit_data    (cfg_msg_transmit_data),
    .cfg_msg_transmit_done    (cfg_msg_transmit_done),

    .cfg_fc_ph   (cfg_fc_ph),
    .cfg_fc_pd   (cfg_fc_pd),
    .cfg_fc_nph  (cfg_fc_nph),
    .cfg_fc_npd  (cfg_fc_npd),
    .cfg_fc_cplh (cfg_fc_cplh),
    .cfg_fc_cpld (cfg_fc_cpld),
    .cfg_fc_sel  (cfg_fc_sel),

    .cfg_dsn               (cfg_dsn),
    .cfg_power_state_change_ack  (cfg_power_state_change_ack),
    .cfg_power_state_change_interrupt (cfg_power_state_change_interrupt),
    .cfg_err_cor_in        (cfg_err_cor_in),
    .cfg_err_uncor_in      (cfg_err_uncor_in),

    .cfg_flr_in_process    (cfg_flr_in_process),
    .cfg_flr_done          (cfg_flr_done),
    .cfg_vf_flr_in_process (cfg_vf_flr_in_process),
    .cfg_vf_flr_done       (cfg_vf_flr_done),
    .cfg_vf_flr_func_num   (cfg_vf_flr_func_num),

    .cfg_link_training_enable (cfg_link_training_enable),

    .cfg_ds_port_number      (cfg_ds_port_number),
    .cfg_hot_reset_in        (cfg_hot_reset_out),
    .cfg_config_space_enable (cfg_config_space_enable),
    .cfg_req_pm_transition_l23_ready (cfg_req_pm_transition_l23_ready),

  // RP only
    .cfg_hot_reset_out   (cfg_hot_reset_in),

    .cfg_ds_bus_number      (cfg_ds_bus_number),
    .cfg_ds_device_number   (cfg_ds_device_number),
    .cfg_ds_function_number (),

    //-------------------------------------------------------------------------------------//
    // EP Only                                                                             //
    //-------------------------------------------------------------------------------------//
    .cfg_interrupt_msi_attr        (cfg_interrupt_msi_attr),
    .cfg_interrupt_msi_data        (cfg_interrupt_msi_data),
    .cfg_interrupt_msi_enable      (cfg_interrupt_msi_enable),
    .cfg_interrupt_msi_function_number (cfg_interrupt_msi_function_number),
    .cfg_interrupt_msi_int         (cfg_interrupt_msi_int),
    .cfg_interrupt_msi_mask_update (cfg_interrupt_msi_mask_update),
    .cfg_interrupt_msi_mmenable    (cfg_interrupt_msi_mmenable[5:0]),
    .cfg_interrupt_msi_pending_status (cfg_interrupt_msi_pending_status),
    .cfg_interrupt_msi_select      (cfg_interrupt_msi_select),
    .cfg_interrupt_msi_sent        (cfg_interrupt_msi_sent),
    .cfg_interrupt_msi_fail        (cfg_interrupt_msi_fail),
    .cfg_interrupt_msi_tph_present (cfg_interrupt_msi_tph_present),
    .cfg_interrupt_msi_tph_st_tag  (cfg_interrupt_msi_tph_st_tag),
    .cfg_interrupt_msi_tph_type    (cfg_interrupt_msi_tph_type),
    .cfg_interrupt_msi_vf_enable   (6'b0),
    .cfg_interrupt_msix_enable     (4'b0),
    .cfg_interrupt_msix_int        (),
    .cfg_dpa_substate_change       (2'b0),
    
    // Interrupt Interface Signals
    .cfg_interrupt_int     (cfg_interrupt_int),
    .cfg_interrupt_pending (cfg_interrupt_pending),
    .cfg_interrupt_sent    (cfg_interrupt_sent)
  );



//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // assign LED outputs
  wire [7:0] leds;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule
