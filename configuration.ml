(* 
 * prooftree --- proof tree display for Proof General
 * 
 * Copyright (C) 2011 Hendrik Tews
 * 
 * This file is part of "prooftree".
 * 
 * "prooftree" is free software: you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 * 
 * "prooftree" is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License in file COPYING in this or one of the parent
 * directories for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with "prooftree". If not, see <http://www.gnu.org/licenses/>.
 * 
 * $Id: configuration.ml,v 1.18 2011/08/04 12:54:42 tews Exp $
 *)


(** Configuration *)

open Gtk_ext

(**/**)
module U = Unix
(**/**)


(*****************************************************************************
 *****************************************************************************)
(** {2 Configuration record and global variables} *)

let config_file_location = 
  Filename.concat
    (Sys.getenv "HOME")
    ".prooftree"

type t = {
  turnstile_radius : int;
  turnstile_left_bar_x_offset : int;
  turnstile_left_bar_y_offset : int;
  turnstile_horiz_bar_x_offset : int;
  turnstile_line_width : int;
  turnstile_number_x_offset : int;

  proof_command_length : int;

  subtree_sep : int;
  line_sep : int;

  level_distance : int;

  node_window_max_lines : int;

  button_1_drag_acceleration : float;

  proof_tree_font : string;
  sequent_font : string;

  proved_color : (int * int * int);	(* (red, green, blue) *)
  current_color : (int * int * int);
  cheated_color : (int * int * int);

  display_tooltips : bool;

  default_width_proof_tree_window : int;
  default_height_proof_tree_window : int;

  internal_sequent_window_lines : int;

  debug_mode : bool;
  copy_input : bool;
  copy_input_file : string;
}


let update_sizes config =
  let radius = config.turnstile_radius in
  { config with 
      turnstile_left_bar_x_offset = 
        int_of_float(-0.23 *. (float_of_int radius) +. 0.5);
      turnstile_left_bar_y_offset =
        int_of_float(0.65 *. (float_of_int radius) +. 0.5);
      turnstile_horiz_bar_x_offset =
        int_of_float(0.7 *. (float_of_int radius) +. 0.5);

      turnstile_number_x_offset = -(config.turnstile_line_width + 1);
  }

let default_configuration = 
  let radius = 10 in
  let blue = GDraw.color (`NAME "blue") in
  let brown = GDraw.color (`NAME "brown") in
  let red = GDraw.color (`NAME "red") in
  let c = {
    turnstile_radius = radius;
    turnstile_line_width = 2;
    proof_command_length = 15;
    subtree_sep = 5;
    line_sep = 3;
    level_distance = 38;

    turnstile_left_bar_x_offset = 0;
    turnstile_left_bar_y_offset = 0;
    turnstile_horiz_bar_x_offset = 0;
    turnstile_number_x_offset = 0;

    node_window_max_lines = 10;

    button_1_drag_acceleration = 4.0;

    proof_tree_font = "Sans 8";
    sequent_font = "Sans 8";

    proved_color = 
      (Gdk.Color.red blue, Gdk.Color.green blue, Gdk.Color.blue blue);
    current_color = 
      (Gdk.Color.red brown, Gdk.Color.green brown, Gdk.Color.blue brown);
    cheated_color = 
      (Gdk.Color.red red, Gdk.Color.green red, Gdk.Color.blue red);

    display_tooltips = true;

    default_width_proof_tree_window = 400;
    default_height_proof_tree_window = 400;

    internal_sequent_window_lines = 1;

    debug_mode = false;
    copy_input = false;
    copy_input_file = "/tmp/prooftree.log";
  }
  in
  update_sizes c


let current_config = ref default_configuration


let proof_tree_font_desc = 
  ref(GPango.font_description default_configuration.proof_tree_font)

let sequent_font_desc = 
  ref(GPango.font_description default_configuration.sequent_font)

let proved_gdk_color = 
  ref(GDraw.color (`RGB default_configuration.proved_color))

let current_gdk_color =
  ref(GDraw.color (`RGB default_configuration.current_color))

let cheated_gdk_color =
  ref(GDraw.color (`RGB default_configuration.cheated_color))

let update_font_and_color () =
  proof_tree_font_desc :=
    GPango.font_description !current_config.proof_tree_font;
  sequent_font_desc :=
    GPango.font_description !current_config.sequent_font;
  proved_gdk_color :=
    GDraw.color (`RGB !current_config.proved_color);
  current_gdk_color :=
    GDraw.color (`RGB !current_config.current_color);
  cheated_gdk_color :=
    GDraw.color (`RGB !current_config.cheated_color)


(** This function reference solves the recursive module dependency
    between modules {!Proof_tree}, {!Input} and this module. It is
    filled with {!Main.configuration_updated} when [Main] is
    initialized.
*)
let configuration_updated_callback = ref (fun () -> ())


let update_configuration c =
    current_config := c;
    update_font_and_color ();
    !configuration_updated_callback ()


let geometry_string = ref ""


(*****************************************************************************
 *****************************************************************************)
(** {2 Save / Restore configuration records} *)

let config_file_header_v_1 = "Prooftree configuration file version 01\n"

let write_config_file file_name (config : t) =
  let oc = open_out_bin file_name in
  output_string oc config_file_header_v_1;
  Marshal.to_channel oc config [];
  close_out oc

let read_config_file file_name : t =
  let header_len = String.length config_file_header_v_1 in
  let header = String.create header_len in
  let ic = open_in_bin file_name in
  really_input ic header 0 header_len;
  if header = config_file_header_v_1 then begin
    let c = (Marshal.from_channel ic : t) in 
    close_in ic;
    c
  end
  else failwith "Invalid configuration file"

let try_load_config_file () =
  let copt =
    try
      Some(read_config_file config_file_location)
    with
      | e -> None
  in
  match copt with
    | None -> ()
    | Some c -> update_configuration c


(*****************************************************************************
 *****************************************************************************)
(** {2 Configuration window} *)


let config_window = ref None

class config_window (top_window : GWindow.window)
  line_width_spinner
  turnstile_size_spinner
  line_sep_spinner
  subtree_sep_spinner
  command_length_spinner
  level_dist_spinner
  tree_font_button
  sequent_font_button
  proved_color_button
  current_color_button
  cheated_color_button
  drag_accel_spinner
  tooltip_check_box
  default_size_width_spinner default_size_height_spinner
  internal_seq_lines_spinner
  debug_check_box
  tee_file_box_check_box 
  tee_file_name_label tee_file_name_entry tee_file_name_button
  tooltip_misc_objects  
  =
object (self)

  val line_width_adjustment = line_width_spinner#adjustment
  val turnstile_size_adjustment = turnstile_size_spinner#adjustment
  val line_sep_adjustment = line_sep_spinner#adjustment
  val subtree_sep_adjustment = subtree_sep_spinner#adjustment
  val command_length_adjustment = command_length_spinner#adjustment
  val level_dist_adjustment = level_dist_spinner#adjustment
  val drag_accel_adjustment = drag_accel_spinner#adjustment
  val default_size_width_adjustment = default_size_width_spinner#adjustment
  val default_size_height_adjustment = default_size_height_spinner#adjustment
  val internal_seq_lines_adjustment = internal_seq_lines_spinner#adjustment

  method present = top_window#present()

  method set_configuration conf =
    line_width_adjustment#set_value (float_of_int conf.turnstile_line_width);
    turnstile_size_adjustment#set_value (float_of_int conf.turnstile_radius);
    subtree_sep_adjustment#set_value (float_of_int conf.subtree_sep);
    line_sep_adjustment#set_value (float_of_int conf.line_sep);
    command_length_adjustment#set_value (float_of_int conf.proof_command_length);
    level_dist_adjustment#set_value (float_of_int conf.level_distance);
    tree_font_button#set_font_name conf.proof_tree_font;
    sequent_font_button#set_font_name conf.sequent_font;
    proved_color_button#set_color (GDraw.color (`RGB conf.proved_color));
    current_color_button#set_color (GDraw.color (`RGB conf.current_color));
    cheated_color_button#set_color (GDraw.color (`RGB conf.cheated_color));
    drag_accel_adjustment#set_value conf.button_1_drag_acceleration;
    tooltip_check_box#set_active conf.display_tooltips;
    default_size_width_adjustment#set_value
      (float_of_int conf.default_width_proof_tree_window);
    default_size_height_adjustment#set_value
      (float_of_int conf.default_height_proof_tree_window);
    internal_seq_lines_adjustment#set_value
      (float_of_int conf.internal_sequent_window_lines);
    debug_check_box#set_active conf.debug_mode;
    tee_file_box_check_box#set_active conf.copy_input;
    tee_file_name_entry#set_text conf.copy_input_file;
    ()

  method reset_to_default () =
    self#set_configuration default_configuration

  method toggle_tooltips () =
    let flag = tooltip_check_box#active in
    List.iter (fun misc -> misc#set_has_tooltip flag) tooltip_misc_objects;
    ()

  method tee_file_toggle () =
    let flag = tee_file_box_check_box#active in
    tee_file_name_label#misc#set_sensitive flag;
    tee_file_name_entry#misc#set_sensitive flag;
    tee_file_name_button#misc#set_sensitive flag;
    ()

  method tee_file_button_click () =
    let file_chooser = GWindow.file_chooser_dialog 
      ~action:`SAVE
      ~parent:top_window
      ~destroy_with_parent:true
      ~title:"Prooftree log file selection"
      ~focus_on_map:true
      ~modal:true ()
    in
    file_chooser#add_select_button "Select" `SELECT;
    file_chooser#add_button "Cancel" `CANCEL;
    ignore(file_chooser#set_current_folder 
	     (Filename.dirname tee_file_name_entry#text));
    (match file_chooser#run() with
      | `SELECT -> 
	(match file_chooser#filename with
	  | None -> ()
	  | Some file -> tee_file_name_entry#set_text file
	)
      | `CANCEL
      | `DELETE_EVENT -> ()
    );
    file_chooser#destroy();
    ()

  method private extract_configuration =
    let round_to_int f = int_of_float(f +. 0.5) in
    let c = {
      turnstile_radius = round_to_int turnstile_size_adjustment#value;
      turnstile_line_width = round_to_int line_width_adjustment#value;
      proof_command_length = round_to_int command_length_adjustment#value;
      subtree_sep = round_to_int subtree_sep_adjustment#value;
      line_sep = round_to_int line_sep_adjustment#value;
      level_distance = round_to_int level_dist_adjustment#value;

      turnstile_left_bar_x_offset = 0;
      turnstile_left_bar_y_offset = 0;
      turnstile_horiz_bar_x_offset = 0;
      turnstile_number_x_offset = 0;

      node_window_max_lines = 10;	(* XXX configure this *)

      button_1_drag_acceleration = drag_accel_adjustment#value;

      proof_tree_font = tree_font_button#font_name;
      sequent_font = sequent_font_button#font_name;

      proved_color = (let c = proved_color_button#color in
		      (Gdk.Color.red c, Gdk.Color.green c, Gdk.Color.blue c));
      current_color = (let c = current_color_button#color in
		       (Gdk.Color.red c, Gdk.Color.green c, Gdk.Color.blue c));
      cheated_color = (let c = cheated_color_button#color in
		       (Gdk.Color.red c, Gdk.Color.green c, Gdk.Color.blue c));

      display_tooltips = tooltip_check_box#active;

      default_width_proof_tree_window = 
	round_to_int default_size_width_adjustment#value;
      default_height_proof_tree_window = 
	round_to_int default_size_height_adjustment#value;

      internal_sequent_window_lines =
	round_to_int internal_seq_lines_adjustment#value;

      debug_mode = debug_check_box#active;
      copy_input = tee_file_box_check_box#active;
      copy_input_file = tee_file_name_entry#text;
    }
    in
    update_sizes c

  method apply () =
    update_configuration (self#extract_configuration)

  method save () = 
    let do_save = ref true in
    if self#extract_configuration <> !current_config
    then begin
      let proceed_dialog = GWindow.message_dialog 
	~message:"The save operation writes the current configuration \
                  record to disk. However, the current configuration \
                  record differs from what the configuration dialog now \
                  shows (because there are changes that have not been \
                  applied). Proceed anyway?"
	~message_type:`QUESTION
	~buttons:GWindow.Buttons.yes_no ()
      in
      (match proceed_dialog#run () with
	| `YES -> ()
	| `NO 
	| `DELETE_EVENT -> do_save := false
      );
      proceed_dialog#destroy ()
    end;
    if !do_save 
    then
      try
	write_config_file config_file_location !current_config
      with
	| e ->
	  let backtrace = Printexc.get_backtrace () in
	  let buf = Buffer.create 4095 in
	  let print_backtrace = ref !current_config.debug_mode in
	  (match e with 
	    | e ->
	      Buffer.add_string buf "Internal error: Escaping exception ";
	      Buffer.add_string buf (Printexc.to_string e);
	      Buffer.add_string buf " in write_config_file";
	      (match e with
		| U.Unix_error(error, _func, _info) ->
		  Buffer.add_char buf '\n';
		  Buffer.add_string buf (U.error_message error);
		| _ -> ()
	      )
	  );
	  if !print_backtrace then begin
	    Buffer.add_char buf '\n';
	    Buffer.add_string buf backtrace;
	  end;
	  prerr_endline (Buffer.contents buf);
	  run_message_dialog (Buffer.contents buf) `WARNING;
	  ()


  method restore () = 
    try
      let c = read_config_file config_file_location in
      self#set_configuration c;
      update_configuration c
    with
      | e ->
	let backtrace = Printexc.get_backtrace () in
	let buf = Buffer.create 4095 in
	let print_backtrace = ref !current_config.debug_mode in
	(match e with 
	  | e ->
	    Buffer.add_string buf "Internal error: Escaping exception ";
	    Buffer.add_string buf (Printexc.to_string e);
	    Buffer.add_string buf " in read_config_file";
	    (match e with
	      | U.Unix_error(error, _func, _info) ->
		Buffer.add_char buf '\n';
		Buffer.add_string buf (U.error_message error);
	      | _ -> ()
	    )
	);
	if !print_backtrace then begin
	  Buffer.add_char buf '\n';
	  Buffer.add_string buf backtrace;
	end;
	prerr_endline (Buffer.contents buf);
	run_message_dialog (Buffer.contents buf) `WARNING;
	()
	


  method destroy () =
    config_window := None;
    top_window#destroy()
    
  method ok () =
    self#apply ();
    self#destroy ()

end

let adjustment_set_pos_int ?(lower = 1.0) (adjustment : GData.adjustment) =
  adjustment#set_bounds
    ~lower ~upper:100.0
    ~step_incr:1.0 ~page_incr:1.0 ()


let make_config_window () =
  let top_window = GWindow.window () in
  let top_v_box = GPack.vbox ~packing:top_window#add () in
  let _config_title = GMisc.label
    ~markup:"<big><b>Prooftree Configuration</b></big>"
    ~xpad:10 ~ypad:10
    ~packing:top_v_box#pack () in

  (****************************************************************************
   *
   * tree configuration frame 
   *
   ****************************************************************************)
  let tree_frame = GBin.frame 
    ~label:"Tree Layout Parameters"
    ~border_width:5
    ~packing:top_v_box#pack () in
  let tree_frame_table = GPack.table 
    (* ~columns:2 ~rows:2 *) ~border_width:5
    ~packing:tree_frame#add () in
  let _middle_separator = GMisc.label ~text:"" ~xpad:7
    ~packing:(tree_frame_table#attach ~left:2 ~top:0) () in
  let _right_separator = GMisc.label ~text:"" ~xpad:2
    ~packing:(tree_frame_table#attach ~left:5 ~top:0) () in

  (* Line width *)
  let line_width_tooltip = "Line width of all lines" in
  let line_width_label = GMisc.label
    ~text:"Line width" ~xalign:0.0 ~xpad:5
    ~packing:(tree_frame_table#attach ~left:0 ~top:0) () in
  let line_width_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true 
    ~packing:(tree_frame_table#attach ~left:1 ~top:0) () in
  adjustment_set_pos_int line_width_spinner#adjustment;
  line_width_spinner#adjustment#set_value 
    (float_of_int !current_config.turnstile_line_width);
  line_width_label#misc#set_tooltip_text line_width_tooltip;
  line_width_spinner#misc#set_tooltip_text line_width_tooltip;

  (* turnstile radius *)
  let turnstile_size_tooltip = 
    "Radius of the circle around the current turnstile; determines \
     the size of the turnstile as well" in
  let turnstile_size_label = GMisc.label
    ~text:"Turnstile size" ~xalign:0.0 ~xpad:5
    ~packing:(tree_frame_table#attach ~left:0 ~top:1) () in
  let turnstile_size_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(tree_frame_table#attach ~left:1 ~top:1) () in
  adjustment_set_pos_int turnstile_size_spinner#adjustment;
  turnstile_size_spinner#adjustment#set_value
    (float_of_int !current_config.turnstile_radius);
  turnstile_size_label#misc#set_tooltip_text turnstile_size_tooltip;
  turnstile_size_spinner#misc#set_tooltip_text turnstile_size_tooltip;

  (* line_sep *)
  let line_sep_tooltip = 
    "Gap between the node connecting lines and the nodes" in
  let line_sep_label = GMisc.label
    ~text:"Line gap" ~xalign:0.0 ~xpad:5
    ~packing:(tree_frame_table#attach ~left:0 ~top:2) () in
  let line_sep_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(tree_frame_table#attach ~left:1 ~top:2) () in
  adjustment_set_pos_int ~lower:0.0 line_sep_spinner#adjustment;
  line_sep_spinner#adjustment#set_value
    (float_of_int !current_config.line_sep);
  line_sep_label#misc#set_tooltip_text line_sep_tooltip;
  line_sep_spinner#misc#set_tooltip_text line_sep_tooltip;

  (* subtree_sep *)
  let subtree_sep_tooltip =
    "Additional padding added to the width of each node in the proof tree" in
  let subtree_sep_label = GMisc.label
    ~text:"Node padding" ~xalign:0.0 ~xpad:5
    ~packing:(tree_frame_table#attach ~left:3 ~top:0) () in
  let subtree_sep_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(tree_frame_table#attach ~left:4 ~top:0) () in
  adjustment_set_pos_int ~lower:0.0 subtree_sep_spinner#adjustment;
  subtree_sep_spinner#adjustment#set_value
    (float_of_int !current_config.subtree_sep);
  subtree_sep_label#misc#set_tooltip_text subtree_sep_tooltip;
  subtree_sep_spinner#misc#set_tooltip_text subtree_sep_tooltip;

  (* proof_command_length *)
  let command_length_tooltip = 
    "Number of characters displayed for proof commands" in
  let command_length_label = GMisc.label
    ~text:"Command length" ~xalign:0.0 ~xpad:5
    ~packing:(tree_frame_table#attach ~left:3 ~top:1) () in
  let command_length_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(tree_frame_table#attach ~left:4 ~top:1) () in
  adjustment_set_pos_int command_length_spinner#adjustment;
  command_length_spinner#adjustment#set_value
    (float_of_int !current_config.proof_command_length);
  command_length_label#misc#set_tooltip_text command_length_tooltip;
  command_length_spinner#misc#set_tooltip_text command_length_tooltip;

  (* level distance *)
  let level_dist_tooltip = "Vertical distance between neighboring nodes" in
  let level_dist_label = GMisc.label
    ~text:"Vertical distance" ~xpad:5
    ~packing:(tree_frame_table#attach ~left:3 ~top:2) () in
  let level_dist_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(tree_frame_table#attach ~left:4 ~top:2) () in
  adjustment_set_pos_int level_dist_spinner#adjustment;
  level_dist_spinner#adjustment#set_value
    (float_of_int !current_config.level_distance);
  level_dist_label#misc#set_tooltip_text level_dist_tooltip;
  level_dist_spinner#misc#set_tooltip_text level_dist_tooltip;

  (****************************************************************************
   *
   * Fonts
   *
   ****************************************************************************)
  let font_frame = GBin.frame 
    ~label:"Fonts"
    ~border_width:5
    ~packing:top_v_box#pack () in
  let font_frame_table = GPack.table
    ~border_width:5 ~packing:font_frame#add () in

  (* tree font *)
  let tree_font_tooltip = "Font for proof commands in the proof tree display" in
  let tree_font_label = GMisc.label
    ~text:"Proof Tree" ~xalign:0.0 ~xpad:5
    ~packing:(font_frame_table#attach ~left:0 ~top:0) () in
  let tree_font_button = GButton.font_button
    ~title:"Proof Tree Font"
    ~font_name:!current_config.proof_tree_font
    ~packing:(font_frame_table#attach ~left:1 ~top:0) () in
  tree_font_button#set_use_size true;
  tree_font_button#set_use_font true;
  tree_font_label#misc#set_tooltip_text tree_font_tooltip;
  tree_font_button#misc#set_tooltip_text tree_font_tooltip;

  (* sequent font *)
  let sequent_font_tooltip = "Font for sequent and proof command windows" in
  let sequent_font_label = GMisc.label
    ~text:"Sequent window" ~xalign:0.0 ~xpad:5
    ~packing:(font_frame_table#attach ~left:0 ~top:1) () in
  let sequent_font_button = GButton.font_button
    ~title:"Sequent Window Font"
    ~font_name:!current_config.sequent_font
    ~packing:(font_frame_table#attach ~left:1 ~top:1) () in
  sequent_font_button#set_use_size true;
  sequent_font_button#set_use_font true;
  sequent_font_label#misc#set_tooltip_text sequent_font_tooltip;
  sequent_font_button#misc#set_tooltip_text sequent_font_tooltip;

  (****************************************************************************
   *
   * Colors
   *
   ****************************************************************************)
  let color_frame = GBin.frame 
    ~label:"Colors"
    ~border_width:5
    ~packing:top_v_box#pack () in
  let color_frame_table = GPack.table
    ~border_width:5 ~packing:color_frame#add () in
  let _middle_left_separator = GMisc.label ~text:"" ~xpad:4
    ~packing:(color_frame_table#attach ~left:2 ~top:0) () in
  let _middle_right_separator = GMisc.label ~text:"" ~xpad:4
    ~packing:(color_frame_table#attach ~left:5 ~top:0) () in
  let _right_separator = GMisc.label ~text:"" ~xpad:2
    ~packing:(color_frame_table#attach ~left:8 ~top:0) () in

  (* proved color *)
  let proved_color_tooltip = "Color for proved branches" in
  let proved_color_label = GMisc.label
    ~text:"Proved" ~xalign:0.0 ~xpad:5
    ~packing:(color_frame_table#attach ~left:0 ~top:0) () in
  let proved_color_button = GButton.color_button
    ~title:"Proved Branches Color"
    ~color:!proved_gdk_color
    ~packing:(color_frame_table#attach ~left:1 ~top:0) () in
  (* proved_color_button#set_use_alpha true; *)
  proved_color_label#misc#set_tooltip_text proved_color_tooltip;
  proved_color_button#misc#set_tooltip_text proved_color_tooltip;

  (* current color *)
  let current_color_tooltip = "Color for the current branch" in
  let current_color_label = GMisc.label
    ~text:"Current" ~xalign:0.0 ~xpad:5
    ~packing:(color_frame_table#attach ~left:3 ~top:0) () in
  let current_color_button = GButton.color_button
    ~title:"Current Branch Color"
    ~color:!current_gdk_color
    ~packing:(color_frame_table#attach ~left:4 ~top:0) () in
  (* current_color_button#set_use_alpha true; *)
  current_color_label#misc#set_tooltip_text current_color_tooltip;
  current_color_button#misc#set_tooltip_text current_color_tooltip;

  (* cheated color *)
  let cheated_color_tooltip = 
    "Color for branches terminated with a cheating proof command" in
  let cheated_color_label = GMisc.label
    ~text:"Cheated" ~xalign:0.0 ~xpad:5
    ~packing:(color_frame_table#attach ~left:6 ~top:0) () in
  let cheated_color_button = GButton.color_button
    ~title:"Cheated Branches Color"
    ~color:!cheated_gdk_color
    ~packing:(color_frame_table#attach ~left:7 ~top:0) () in
  (* cheated_color_button#set_use_alpha true; *)
  cheated_color_label#misc#set_tooltip_text cheated_color_tooltip;
  cheated_color_button#misc#set_tooltip_text cheated_color_tooltip;

  (****************************************************************************
   *
   * Misc
   *
   ****************************************************************************)
  let misc_frame = GBin.frame 
    ~label:"Miscellaneous"
    ~border_width:5
    ~packing:top_v_box#pack () in
  let misc_frame_table = GPack.table 
    (* ~columns:2 ~rows:2 *) ~border_width:5
    ~packing:misc_frame#add () in

  (* tooltips *)
  let tooltip_alignment = GBin.alignment
    ~padding:(0,0,3,0)
    ~packing:(misc_frame_table#attach ~left:0 ~top:0) () in
  let tooltip_check_box = GButton.check_button
    ~label:"Display tooltips"
    ~active:!current_config.display_tooltips
    ~packing:tooltip_alignment#add () in

  (* drag accel *)
  let drag_accel_tooltip = 
    "Acceleration for dragging the viewport to the proof tree" in
  let drag_accel_label = GMisc.label
    ~text:"Drag acceleration" ~xalign:0.0 ~xpad:5
    ~packing:(misc_frame_table#attach ~left:0 ~top:1) () in
  let drag_accel_spinner = GEdit.spin_button
    ~digits:2 ~numeric:true
    ~packing:(misc_frame_table#attach ~left:1 ~top:1) () in
  drag_accel_spinner#adjustment#set_bounds
    ~lower:(-99.0) ~upper:99.0
    ~step_incr:0.01 ~page_incr:1.0 ();
  drag_accel_spinner#adjustment#set_value
    !current_config.button_1_drag_acceleration;
  drag_accel_label#misc#set_tooltip_text drag_accel_tooltip;
  drag_accel_spinner#misc#set_tooltip_text drag_accel_tooltip;

  (* default size *)
  let default_size_tooltip = "Size for newly created proof tree windows" in
  let default_size_label = GMisc.label
    ~text:"Default window size" ~xalign:0.0 ~xpad:5
    ~packing:(misc_frame_table#attach ~left:0 ~top:2) () in
  let default_size_width_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(misc_frame_table#attach ~left:1 ~top:2) () in
  default_size_width_spinner#adjustment#set_bounds
    ~lower:(-9999.0) ~upper:9999.0
    ~step_incr:1.0 ~page_incr:100.0 ();
  default_size_width_spinner#adjustment#set_value
    (float_of_int !current_config.default_width_proof_tree_window);
  let _x_label = GMisc.label
    ~text:"\195\151" (* multiplication sign U+00D7 *)
    ~xpad:5
    ~packing:(misc_frame_table#attach ~left:2 ~top:2) () in
  let default_size_height_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(misc_frame_table#attach ~left:3 ~top:2) () in
  default_size_height_spinner#adjustment#set_bounds
    ~lower:(-9999.0) ~upper:9999.0
    ~step_incr:1.0 ~page_incr:100.0 ();
  default_size_height_spinner#adjustment#set_value
    (float_of_int !current_config.default_height_proof_tree_window);
  default_size_label#misc#set_tooltip_text default_size_tooltip;
  default_size_width_spinner#misc#set_tooltip_text default_size_tooltip;
  default_size_height_spinner#misc#set_tooltip_text default_size_tooltip;

  (* internal sequent window lines *)
  let internal_seq_lines_tooltip = 
    "Initial height (in lines) of the sequent window 
     below the proof tree display" 
  in
  let internal_seq_lines_label = GMisc.label
    ~text:"Int. Sequent window" ~xalign:0.0 ~xpad:5
    ~packing:(misc_frame_table#attach ~left:0 ~top:3) () in
  let internal_seq_lines_spinner = GEdit.spin_button
    ~digits:0 ~numeric:true
    ~packing:(misc_frame_table#attach ~left:1 ~top:3) () in
  adjustment_set_pos_int ~lower:0.0 internal_seq_lines_spinner#adjustment;
  internal_seq_lines_spinner#adjustment#set_value
    (float_of_int !current_config.internal_sequent_window_lines);
  internal_seq_lines_label#misc#set_tooltip_text internal_seq_lines_tooltip;
  internal_seq_lines_spinner#misc#set_tooltip_text internal_seq_lines_tooltip;

  (* non-configurable config-file *)
  let config_file_tooltip = 
    "The configuration file is determined at compilation time" in
  let config_file_label = GMisc.label
    ~text:"Configuration file"
    ~xalign:0.0 ~xpad:5
    ~packing:(misc_frame_table#attach ~left:0 ~top:4) () in
  let config_file_alignment = GBin.alignment
    ~padding:(0,0,3,0)
    ~packing:(misc_frame_table#attach ~left:1 ~right:4 ~top:4) () in
  let _config_file_file = GMisc.label
    ~text:config_file_location
    ~xalign:0.0
    ~packing:config_file_alignment#add () in
  config_file_label#misc#set_tooltip_text config_file_tooltip;
  config_file_alignment#misc#set_tooltip_text config_file_tooltip;

  (****************************************************************************
   *
   * Debugging Options
   *
   ****************************************************************************)
  let debug_frame = GBin.frame 
    ~label:"Debugging Options"
    ~border_width:5
    ~packing:top_v_box#pack () in
  let debug_frame_table = GPack.table 
    (* ~columns:2 ~rows:2 *) ~border_width:5
    ~packing:debug_frame#add () in

  (* debug *)
  let debug_tooltip = "Provide more information on fatal error conditions" in
  let debug_alignment = GBin.alignment
    ~padding:(0,0,3,0)
    ~packing:(debug_frame_table#attach ~left:0 ~right:4 ~top:0) () in
  let debug_check_box = GButton.check_button
    ~label:"More debug information"
    ~active:!current_config.debug_mode
    ~packing:debug_alignment#add () in
  debug_alignment#misc#set_tooltip_text debug_tooltip;

  (* tee file checkbox*)
  let tee_file_box_tooltip = "Save all input from Proof General in log file" in
  let tee_file_box_alignment = GBin.alignment
    ~padding:(0,0,3,0)
    ~packing:(debug_frame_table#attach ~left:0 ~right:4 ~top:1) () in
  let tee_file_box_check_box = GButton.check_button
    ~label:"Log Proof General input"
    ~active:!current_config.copy_input
    ~packing:tee_file_box_alignment#add () in
  tee_file_box_alignment#misc#set_tooltip_text tee_file_box_tooltip;

  (* tee file filename *)
  let tee_file_name_label = GMisc.label
    ~text:"Log file" ~xalign:0.0 ~xpad:5
    ~packing:(debug_frame_table#attach ~left:0 ~top:2) () in
  let tee_file_name_entry = GEdit.entry
    ~text:!current_config.copy_input_file
    (* ~max_length:25 *)
    ~packing:(debug_frame_table#attach ~left:1 ~top:2) () in
  let _button_separator = GMisc.label ~text:"" ~xpad:5
    ~packing:(debug_frame_table#attach ~left:2 ~top:2) () in
  let tee_file_name_button = GButton.button
    ~label:"Log-file selection dialog"
    ~packing:(debug_frame_table#attach ~left:3 ~top:2) () in


  (****************************************************************************
   *
   * bottom button box
   *
   ****************************************************************************)
  (* 
   * let _separator = GMisc.separator `HORIZONTAL 
   *   ~packing:top_v_box#pack () in
   *)
  let button_box = GPack.hbox 
    ~spacing:5 ~border_width:5 ~packing:top_v_box#pack () in
  let reset_button = GButton.button 
    ~label:"Set defaults" ~packing:button_box#pack () in
  let apply_button = GButton.button
    ~label:"Apply" ~packing:button_box#pack () in
  let cancel_button = GButton.button
    ~label:"Cancel" ~packing:button_box#pack () in
  let ok_button = GButton.button
    ~label:"OK" ~packing:button_box#pack () in
  let restore_button = GButton.button
    ~label:"Restore" ~packing:(button_box#pack ~from:`END) () in
  let save_button = GButton.button
    ~label:"Save" ~packing:(button_box#pack ~from:`END) () in
  let config_window = 
    new config_window top_window 
      line_width_spinner
      turnstile_size_spinner
      line_sep_spinner
      subtree_sep_spinner
      command_length_spinner
      level_dist_spinner
      tree_font_button
      sequent_font_button
      proved_color_button
      current_color_button
      cheated_color_button
      drag_accel_spinner
      tooltip_check_box
      default_size_width_spinner default_size_height_spinner
      internal_seq_lines_spinner
      debug_check_box
      tee_file_box_check_box 
      tee_file_name_label tee_file_name_entry tee_file_name_button
      [ line_width_label#misc; line_width_spinner#misc;
	turnstile_size_label#misc; turnstile_size_spinner#misc;
	line_sep_label#misc; line_sep_spinner#misc;
	subtree_sep_label#misc; subtree_sep_spinner#misc;
	command_length_label#misc; command_length_spinner#misc;
	level_dist_label#misc; level_dist_spinner#misc;
	tree_font_label#misc; tree_font_button#misc;
	sequent_font_label#misc; sequent_font_button#misc;
	proved_color_label#misc; proved_color_button#misc;
	current_color_label#misc; current_color_button#misc;
	cheated_color_label#misc; cheated_color_button#misc;
	drag_accel_label#misc; drag_accel_spinner#misc;
	default_size_label#misc; default_size_width_spinner#misc;
	default_size_height_spinner#misc; 
	internal_seq_lines_label#misc; internal_seq_lines_spinner#misc;
	config_file_label#misc;
	config_file_alignment#misc; debug_alignment#misc;
	tee_file_box_alignment#misc;
      ]
  in

  top_window#set_title "Prooftree Configuration";
  config_window#toggle_tooltips ();
  config_window#tee_file_toggle();
  ignore(tooltip_check_box#connect#toggled
	   ~callback:config_window#toggle_tooltips);
  ignore(tee_file_box_check_box#connect#toggled 
	   ~callback:config_window#tee_file_toggle);
  ignore(tee_file_name_button#connect#clicked 
	   ~callback:config_window#tee_file_button_click);
  ignore(top_window#connect#destroy ~callback:config_window#destroy);
  ignore(reset_button#connect#clicked ~callback:config_window#reset_to_default);
  ignore(apply_button#connect#clicked ~callback:config_window#apply);
  ignore(cancel_button#connect#clicked ~callback:config_window#destroy);
  ignore(ok_button#connect#clicked ~callback:config_window#ok);
  ignore(save_button#connect#clicked ~callback:config_window#save);
  ignore(restore_button#connect#clicked ~callback:config_window#restore);
  top_window#show ();

  config_window


let show_config_window () =
  match !config_window with
    | Some w -> w#present
    | None -> config_window := Some(make_config_window ())
