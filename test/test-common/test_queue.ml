open Alcotest_lwt
open Base

let ( let* ) = Lwt.bind

module Make
    (RepoService : Sihl.Data.Repo.Sig.SERVICE)
    (QueueService : Sihl.Queue.Sig.SERVICE) =
struct
  let dispatched_job_gets_processed ctx _ () =
    let has_ran_job = ref false in
    let* () = QueueService.on_init ctx |> Lwt.map Result.ok_or_failwith in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let job =
      Sihl.Queue.create_job ~name:"foo"
        ~input_to_string:(fun () -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ ~input:_ -> Lwt_result.return (has_ran_job := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl.Queue.set_max_tries 3
      |> Sihl.Queue.set_retry_delay Sihl.Utils.Time.OneMinute
    in
    let* () = QueueService.register_jobs ctx ~jobs:[ job ] in
    let* () = QueueService.on_start ctx |> Lwt.map Result.ok_or_failwith in
    let* () = QueueService.dispatch ctx ~job () in
    let* () = Lwt_unix.sleep 1.5 in
    let* () = QueueService.on_stop ctx |> Lwt.map Result.ok_or_failwith in
    let () = Alcotest.(check bool "has processed job" true !has_ran_job) in
    Lwt.return ()

  let two_dispatched_jobs_get_processed ctx _ () =
    let has_ran_job1 = ref false in
    let has_ran_job2 = ref false in
    let* () = QueueService.on_init ctx |> Lwt.map Result.ok_or_failwith in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let job1 =
      Sihl.Queue.create_job ~name:"foo1"
        ~input_to_string:(fun () -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ ~input:_ -> Lwt_result.return (has_ran_job1 := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl.Queue.set_max_tries 3
      |> Sihl.Queue.set_retry_delay Sihl.Utils.Time.OneMinute
    in
    let job2 =
      Sihl.Queue.create_job ~name:"foo2"
        ~input_to_string:(fun () -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ ~input:_ -> Lwt_result.return (has_ran_job2 := true))
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl.Queue.set_max_tries 3
      |> Sihl.Queue.set_retry_delay Sihl.Utils.Time.OneMinute
    in
    let* () = QueueService.register_jobs ctx ~jobs:[ job1; job2 ] in
    let* () = QueueService.on_start ctx |> Lwt.map Result.ok_or_failwith in
    let* () = QueueService.dispatch ctx ~job:job1 () in
    let* () = QueueService.dispatch ctx ~job:job2 () in
    let* () = Lwt_unix.sleep 1.5 in
    let* () = QueueService.on_stop ctx |> Lwt.map Result.ok_or_failwith in
    let () = Alcotest.(check bool "has processed job1" true !has_ran_job1) in
    let () = Alcotest.(check bool "has processed job2" true !has_ran_job1) in
    Lwt.return ()

  let cleans_up_job_after_error ctx _ () =
    let has_cleaned_up_job = ref false in
    let* () = QueueService.on_init ctx |> Lwt.map Result.ok_or_failwith in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let job =
      Sihl.Queue.create_job ~name:"foo"
        ~input_to_string:(fun () -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ ~input:_ -> Lwt_result.fail "didn't work")
        ~failed:(fun _ -> Lwt_result.return (has_cleaned_up_job := true))
        ()
      |> Sihl.Queue.set_max_tries 3
      |> Sihl.Queue.set_retry_delay Sihl.Utils.Time.OneMinute
    in
    let* () = QueueService.register_jobs ctx ~jobs:[ job ] in
    let* () = QueueService.on_start ctx |> Lwt.map Result.ok_or_failwith in
    let* () = QueueService.dispatch ctx ~job () in
    let* () = Lwt_unix.sleep 1.5 in
    let* () = QueueService.on_stop ctx |> Lwt.map Result.ok_or_failwith in
    let () =
      Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job)
    in
    Lwt.return ()

  let cleans_up_job_after_exception ctx _ () =
    let has_cleaned_up_job = ref false in
    let* () = QueueService.on_init ctx |> Lwt.map Result.ok_or_failwith in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let job =
      Sihl.Queue.create_job ~name:"foo"
        ~input_to_string:(fun () -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun _ ~input:_ -> failwith "didn't work")
        ~failed:(fun _ -> Lwt_result.return (has_cleaned_up_job := true))
        ()
      |> Sihl.Queue.set_max_tries 3
      |> Sihl.Queue.set_retry_delay Sihl.Utils.Time.OneMinute
    in
    let* () = QueueService.register_jobs ctx ~jobs:[ job ] in
    let* () = QueueService.on_start ctx |> Lwt.map Result.ok_or_failwith in
    let* () = QueueService.dispatch ctx ~job () in
    let* () = Lwt_unix.sleep 1.5 in
    let* () = QueueService.on_stop ctx |> Lwt.map Result.ok_or_failwith in
    let () =
      Alcotest.(check bool "has cleaned up job" true !has_cleaned_up_job)
    in
    Lwt.return ()

  let inject_custom_context ctx _ () =
    let custom_ctx_key : string Sihl.Core.Ctx.key =
      Sihl.Core.Ctx.create_key ()
    in
    let* () = QueueService.on_init ctx |> Lwt.map Result.ok_or_failwith in
    let* () = RepoService.clean_all ctx |> Lwt.map Result.ok_or_failwith in
    let has_custom_ctx_string = ref false in
    let job =
      Sihl.Queue.create_job ~name:"foo"
        ~with_context:(fun ctx ->
          Sihl.Core.Ctx.add custom_ctx_key "my custom context string" ctx)
        ~input_to_string:(fun () -> None)
        ~string_to_input:(fun _ -> Ok ())
        ~handle:(fun ctx ~input:_ ->
          has_custom_ctx_string :=
            Option.is_some (Sihl.Core.Ctx.find custom_ctx_key ctx);
          Lwt_result.return ())
        ~failed:(fun _ -> Lwt_result.return ())
        ()
      |> Sihl.Queue.set_max_tries 3
      |> Sihl.Queue.set_retry_delay Sihl.Utils.Time.OneMinute
    in
    let* () = QueueService.register_jobs ctx ~jobs:[ job ] in
    let* () = QueueService.on_start ctx |> Lwt.map Result.ok_or_failwith in
    let* () = QueueService.dispatch ctx ~job () in
    let* () = Lwt_unix.sleep 1.5 in
    let* () = QueueService.on_stop ctx |> Lwt.map Result.ok_or_failwith in
    let () =
      Alcotest.(check bool "has custom ctx string" true !has_custom_ctx_string)
    in
    Lwt.return ()

  let test_suite ctx =
    ( "queue",
      [
        test_case "dispatched job gets processed" `Quick
          (dispatched_job_gets_processed ctx);
        test_case "two dispatched job get processed" `Quick
          (two_dispatched_jobs_get_processed ctx);
        test_case "cleans up job after error" `Quick
          (cleans_up_job_after_error ctx);
        test_case "cleans up job after exception" `Quick
          (cleans_up_job_after_exception ctx);
        test_case "inject custom context" `Quick (inject_custom_context ctx);
      ] )
end
