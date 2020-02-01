open Base
open Opium.Std

type status_code = Cohttp.Code.status_code

module Responses = struct
  module type Json = sig
    type t

    val to_yojson : t -> Yojson.Safe.t
  end

  module type Unit = sig
    type t = unit
  end

  module Unit = struct
    type t = unit
  end

  module type No_content = Unit

  module No_content = Unit

  module type Int = sig
    type t = int
  end

  module Int = struct
    type t = int
  end

  module Created = struct
    module type Int = Int

    module Int = Int
  end

  module type Empty_code = sig
    type t = status_code
  end

  module Empty_code = struct
    type t = status_code
  end

  module type Empty_code_headers = sig
    type t = status_code * (string * string) list
  end

  module Empty_code_headers = struct
    type t = status_code * (string * string) list
  end

  module type String = sig
    type t = string
  end

  module String = struct
    type t = string
  end

  module type Json_list = Json

  module type Json_opt = Json

  module type Json_code = Json

  (* TODO - see if we can make using these mandatory *)
  module Json_list (Json : Json) = Json
  module Json_opt (Json : Json) = Json
  module Json_code (Json : Json) = Json
end

module Make = struct
  let caqti_error_responder error = error |> Caqti_error.show |> failwith

  let get_default_error_responder provided_responder =
    Option.value provided_responder ~default:caqti_error_responder

  module Make_response = struct
    module type Make_sig = functor
      (Responses : sig
         type t
       end)
      -> sig
      val f : Responses.t -> Response.t Lwt.t
    end

    module Json (Responses : Responses.Json) = struct
      let f content = `Json (content |> Responses.to_yojson) |> respond'
    end

    module Json_opt (Responses : Responses.Json_opt) = struct
      let f content_opt =
        match content_opt with
        | Some content -> `Json (content |> Responses.to_yojson) |> respond'
        | None -> `String "" |> respond' ~code:`Not_found
    end

    module Json_list (Responses : Responses.Json_list) = struct
      let f content =
        let list_of_json = List.map content ~f:Responses.to_yojson in
        let json_of_list = `List list_of_json in
        `Json json_of_list |> respond'
    end

    module Json_code (Responses : Responses.Json_code) = struct
      let f content =
        let code_string, content_json =
          match Responses.to_yojson content with
          | [%yojson? [ [%y? `String code_string]; [%y? content_json] ]] ->
              (code_string, content_json)
          | _ -> failwith "yo!"
        in
        let code =
          match String.chop_prefix ~prefix:"_" code_string with
          | Some number -> number |> Int.of_string |> Cohttp.Code.status_of_code
          | None -> failwith "yo!"
        in
        `Json content_json |> respond' ~code
    end

    module Empty_code (Responses : Responses.Empty_code) = struct
      let f code = `String "" |> respond' ~code
    end

    module Empty_code_headers (Responses : Responses.Empty_code_headers) =
    struct
      let f (code, headers) =
        `String "" |> respond' ~headers:(Cohttp.Header.of_list headers) ~code
    end

    module String (Responses : Responses.String) = struct
      let f s = `String s |> respond'
    end

    module Created = struct
      module Int (Responses : Responses.Created.Int) (S : Specification.S) =
      struct
        let f id =
          let location = Printf.sprintf "%s/%d" S.path id in
          `String ""
          |> respond'
               ~headers:(Cohttp.Header.of_list [ ("Location", location) ])
               ~code:`Created
      end
    end

    module No_content (Responses : Responses.No_content) = struct
      let f () = `String "" |> respond' ~code:`No_content
    end
  end

  let make_result_response response_f ?error_responder content_result_lwt =
    let error_responder = get_default_error_responder error_responder in
    let%lwt content_result = content_result_lwt in
    let response =
      match content_result with
      | Ok content -> response_f content
      | Error error -> error_responder error |> respond'
    in
    response

  let make_not_result_response response_f content_lwt =
    let%lwt content = content_lwt in
    response_f content

  module Json (Responses : Responses.Json) = struct
    module M = Make_response.Json (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Json_list (Responses : Responses.Json_list) = struct
    module M = Make_response.Json_list (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Json_opt (Responses : Responses.Json_opt) = struct
    module M = Make_response.Json_opt (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Empty_code (Responses : Responses.Empty_code) = struct
    module M = Make_response.Empty_code (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Empty_code_headers (Responses : Responses.Empty_code_headers) = struct
    module M = Make_response.Empty_code_headers (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Created = struct
    module Int (Responses : Responses.Created.Int) (S : Specification.S) =
    struct
      module M = Make_response.Created.Int (Responses) (S)

      let f ?error_responder content_result_lwt =
        make_result_response M.f ?error_responder content_result_lwt
    end
  end

  module No_content (Responses : Responses.No_content) = struct
    module M = Make_response.No_content (Responses)

    let f ?error_responder content_result_lwt =
      make_result_response M.f ?error_responder content_result_lwt
  end

  module Not_result = struct
    module Json (Responses : Responses.Json) = struct
      module M = Make_response.Json (Responses)

      let f = make_not_result_response M.f
    end

    module Json_code (Responses : Responses.Json_code) = struct
      module M = Make_response.Json_code (Responses)

      let f = make_not_result_response M.f
    end

    module Json_list (Responses : Responses.Json_list) = struct
      module M = Make_response.Json_list (Responses)

      let f = make_not_result_response M.f
    end

    module Json_opt (Responses : Responses.Json_opt) = struct
      module M = Make_response.Json_opt (Responses)

      let f = make_not_result_response M.f
    end

    module Empty_code (Responses : Responses.Empty_code) = struct
      module M = Make_response.Empty_code (Responses)

      let f = make_not_result_response M.f
    end

    module Empty_code_headers (Responses : Responses.Empty_code_headers) =
    struct
      module M = Make_response.Empty_code_headers (Responses)

      let f = make_not_result_response M.f
    end

    module String (Responses : Responses.String) = struct
      module M = Make_response.String (Responses)

      let f = make_not_result_response M.f
    end

    module Created = struct
      module Int (Responses : Responses.Created.Int) (S : Specification.S) =
      struct
        module M = Make_response.Created.Int (Responses) (S)

        let f = make_not_result_response M.f
      end
    end

    module No_content (Responses : Responses.No_content) = struct
      module M = Make_response.No_content (Responses)

      let f = make_not_result_response M.f
    end
  end
end