open Core
open Opium.Std
open Controllers

let hello_world =
  get "/" (fun _ ->
      `String "Hello world!\n\nfrom OCaml\n     Ice" |> respond')

let _ =
  let app = App.empty in
  app
  |> Ocoi.Controllers.register_crud "/todos" (module Todo.Crud)
  |> hello_world |> App.run_command