package discord

import "base:runtime"
import "core:sync"
import "core:thread"

Callback_Task_Data :: struct {
	callback:  Event_Callback,
	payload:   rawptr,
	cleanup:   proc(_: rawptr, _: runtime.Allocator),
	allocator: runtime.Allocator,
}

on_component :: proc(client: ^Client, custom_id: string, handler: Component_Handler) {
	client.component_registry[custom_id] = Component_Registration{custom_id = custom_id, handler = handler}
}

on :: proc(client: ^Client, event_name: string, callback: Event_Callback) {
	sync.lock(&client.event_mutex)

	if _, ok := client.event_handlers[event_name]; !ok {
		client.event_handlers[event_name] = make(
			[dynamic]Event_Listener,
			allocator = client.allocator,
		)
	}

	append(&client.event_handlers[event_name], Event_Listener{callback = callback})
	sync.unlock(&client.event_mutex)
}

@(private)
callback_worker :: proc(task: thread.Task) {
	ctx := (^Callback_Task_Data)(task.data)
	defer {
		ctx.cleanup(ctx.payload, ctx.allocator)
		free(ctx)
	}
	ctx.callback(ctx.payload)
}

@(private)
dispatch_event :: proc(client: ^Client, event_name: string, payload: $T) {
	sync.shared_lock(&client.event_mutex)

	listeners, exists := client.event_handlers[event_name]
	if !exists {
		sync.shared_unlock(&client.event_mutex)
		return
	}

	local_listeners := make([]Event_Listener, len(listeners), context.temp_allocator)
	runtime.copy_slice(local_listeners, listeners[:])
	sync.shared_unlock(&client.event_mutex)

	for listener in local_listeners {
		copy_payload := new(T, allocator = client.allocator)
		copy_payload^ = deep_clone(payload, client.allocator)

		task := new(Callback_Task_Data)
		task.callback = listener.callback
		task.payload = copy_payload
		task.allocator = client.allocator
		task.cleanup = proc(p: rawptr, allocator: runtime.Allocator) {
			obj := (^T)(p)
			deep_free(obj^, allocator)
			free(obj)
		}

		thread.pool_add_task(&client.worker_pool, context.allocator, callback_worker, task)
	}
}
