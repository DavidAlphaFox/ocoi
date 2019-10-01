open Codegen
open Core

(* TODO - refactor to remove code shared with db_codegen.ml *)
let make_controller_code module_name resource_attributes =
  let queries_module = "Queries." ^ String.capitalize module_name in
  let create_parameters = parameters_string (without_id resource_attributes) in
  let record_literal = record_names_string resource_attributes "; " in
  Printf.sprintf
    {ocaml|let%%lwt conn = Db.connection

let create %s = %s.create conn %s

module Rud : Ocoi.Controllers.Rud = struct
  include Models.%s

  let index () = %s.all conn

  let show id = %s.show conn id

  let update {%s} =
    %s.update conn {%s}

  let destroy id = %s.destroy conn id
end|ocaml}
    create_parameters queries_module create_parameters
    (String.capitalize module_name)
    queries_module queries_module record_literal queries_module record_literal
    queries_module

let write_controller name tree =
  let controller_name =
    FilePath.concat (FilePath.dirname name)
      ("../controllers/" ^ Filename.basename name)
  in
  let module_name = name |> FilePath.chop_extension |> FilePath.basename in
  let resource_attributes =
    tree |> get_t_node_labels_ast |> get_resource_attributes
  in
  let oc = Out_channel.create controller_name in
  Printf.fprintf oc "%s\n"
    (make_controller_code module_name resource_attributes) ;
  Out_channel.close oc