module PartialCollection : sig
  type controls

  val last : controls -> Data_ql.t option

  val next : controls -> Data_ql.t option

  val previous : controls -> Data_ql.t option

  val first : controls -> Data_ql.t option

  val pp_controls : Format.formatter -> controls -> unit

  val show_controls : controls -> string

  val equal_controls : controls -> controls -> bool

  val controls_to_yojson : controls -> Yojson.Safe.t

  val controls_of_yojson :
    Yojson.Safe.t -> controls Ppx_deriving_yojson_runtime.error_or

  type 'a t = { member : 'a list; total_items : int; controls : controls }

  val create : query:Data_ql.t -> meta:Data_repo.Meta.t -> 'a list -> 'a t

  val controls : 'a t -> controls

  val total_items : 'a t -> int

  val member : 'a t -> 'a list

  val pp : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a t -> unit

  val show : (Format.formatter -> 'a -> unit) -> 'a t -> string

  val equal : ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

  val to_yojson : ('a -> Yojson.Safe.t) -> 'a t -> Yojson.Safe.t

  val of_yojson :
    (Yojson.Safe.t -> 'a Ppx_deriving_yojson_runtime.error_or) ->
    Yojson.Safe.t ->
    'a t Ppx_deriving_yojson_runtime.error_or
end
