external ffToDomType: Dom.eventTarget => Dom.node_like<'a> = "%identity"
external ffToWebDom: Nullable.t<Dom.element> => Nullable.t<Webapi.Dom.Element.t> = "%identity"
type ref =
  | ArrayOfRef(array<React.ref<Nullable.t<Dom.element>>>)
  | RefArray(React.ref<array<Nullable.t<Dom.element>>>)

let useOutsideClick = (
  ~refs: ref,
  ~containerRefs: option<React.ref<Nullable.t<Dom.element>>>=?,
  ~isActive,
  ~events=["click"],
  ~callback,
  (),
) => {
  let eventCallback = UseEvent.useEvent0(callback)
  React.useEffect1(() => {
    if isActive {
      let handleClick = (e: Dom.event) => {
        let targ = Webapi.Dom.Event.target(e)

        let isInsideClick = switch refs {
        | ArrayOfRef(refs) =>
          refs->Array.reduce(false, (acc, ref: React.ref<Nullable.t<Dom.element>>) => {
            let isClickInsideRef = switch ffToWebDom(ref.current)->Nullable.toOption {
            | Some(element) => element->Webapi.Dom.Element.contains(~child=ffToDomType(targ))
            | None => false
            }
            acc || isClickInsideRef
          })
        | RefArray(refs) =>
          refs.current
          ->Array.slice(~start=0, ~end=-1)
          ->Array.reduce(false, (acc, ref: Nullable.t<Dom.element>) => {
            let isClickInsideRef = switch ffToWebDom(ref)->Nullable.toOption {
            | Some(element) => element->Webapi.Dom.Element.contains(~child=ffToDomType(targ))
            | None => false
            }
            acc || isClickInsideRef
          })
        }

        let isClickInsideOfContainer = switch containerRefs {
        | Some(ref) =>
          switch ffToWebDom(ref.current)->Nullable.toOption {
          | Some(element) => element->Webapi.Dom.Element.contains(~child=ffToDomType(targ))
          | None => false
          }
        | None => true
        }

        if !isInsideClick && isClickInsideOfContainer {
          eventCallback()
        }
      }

      Js.Global.setTimeout(() => {
        events->Array.forEach(
          event => {
            Webapi.Dom.window->Webapi.Dom.Window.addEventListener(event, handleClick)
          },
        )
      }, 50)->ignore

      Some(
        () => {
          events->Array.forEach(event =>
            Webapi.Dom.window->Webapi.Dom.Window.removeEventListener(event, handleClick)
          )
        },
      )
    } else {
      None
    }
  }, [isActive])
}
