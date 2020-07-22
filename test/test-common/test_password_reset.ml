open Base

let ( let* ) = Lwt.bind

module Make
    (DbService : Sihl.Data.Db.Sig.SERVICE)
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (UserService : Sihl.User.Sig.SERVICE)
    (PasswordResetService : Sihl.User.PasswordReset.Sig.SERVICE) =
struct
  module UserSeed = Sihl.User.Seed.Make (UserService)

  let reset_password_suceeds _ () =
    let ctx = Sihl.Core.Ctx.empty |> DbService.add_pool in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let* _ =
      Sihl.Test.seed ctx
        (UserSeed.user ~email:"foo@example.com" ~password:"123456789")
    in
    let* token =
      PasswordResetService.create_reset_token ctx ~email:"foo@example.com"
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map (Result.of_option ~error:"User with email not found")
      |> Lwt.map Result.ok_or_failwith
    in
    let token = Sihl.Token.value token in
    let* () =
      PasswordResetService.reset_password ctx ~token ~password:"newpassword"
        ~password_confirmation:"newpassword"
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map Result.ok_or_failwith
    in
    let* _ =
      UserService.login ctx ~email:"foo@example.com" ~password:"newpassword"
      |> Lwt.map Result.ok_or_failwith
      |> Lwt.map Result.ok_or_failwith
    in
    Lwt.return ()
end
