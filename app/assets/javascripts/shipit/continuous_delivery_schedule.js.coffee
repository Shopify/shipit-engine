$(document)
    .on "click", ".continuous-delivery-schedule [data-action='copy-to-all']", (event) -> 
        form = event.target.closest("form");

        mondayStart = form.elements.namedItem("continuous_delivery_schedule[monday_start]").value
        mondayEnd = form.elements.namedItem("continuous_delivery_schedule[monday_end]").value

        Array.from(form.elements).forEach (formElement) ->
            return unless formElement.type == "time"

            if formElement.name.endsWith("_start]")
                formElement.value = mondayStart

            if formElement.name.endsWith("_end]")
                formElement.value = mondayEnd
