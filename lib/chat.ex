defmodule Chat do
  def main(n_users) do
    chat_server_pid = spawn(fn -> chat_server([]) end)

    1..n_users
    |> Enum.map(fn i -> Task.async(fn -> user(chat_server_pid, "user#{i}") end) end)
    |> Enum.map(fn task -> Task.await(task) end)
    |> IO.inspect
  end


  def chat_server(destinations) do
    receive do
      {:join, pid} -> chat_server(destinations ++ [pid])
      {:leave, pid} -> chat_server(List.delete(destinations, pid))
      {:send, message} ->
        Enum.each(destinations, fn destination -> send(destination, {:message, message}) end)
        chat_server(destinations)
    end
  end

  def user(chat_server_pid, username) do
    pid = self()
    inbox_pid = spawn(fn -> user_inbox(pid, []) end)
    add_user(chat_server_pid, inbox_pid)


    first_msg = "Hello from user #{username}"
    write_message(chat_server_pid, {username, first_msg})

    Process.sleep(50)
    send(inbox_pid, :check_messages)
    messages = receive do
      messages -> messages
    end

    second_msg = if length(messages) != 0 do
      {user_first, _} = hd(messages)
      "Hello to user #{user_first}"
    else
      "Bye everyone!"
    end


    write_message(chat_server_pid, {username, second_msg})
    user_delete(chat_server_pid, inbox_pid)

    Process.sleep(50)

    send(inbox_pid, :check_messages)
    send(inbox_pid, :finish)
    messages = receive do
      messages -> messages
    end
    messages
  end

  def add_user(chat_server_pid, user_pid) do
    send(chat_server_pid, {:join, user_pid})
  end

  def user_delete(chat_server_pid, user_pid) do
    send(chat_server_pid, {:leave, user_pid})
  end

  def write_message(chat_server_pid, message) do
    send(chat_server_pid, {:send, message})
  end

  def user_inbox(user_pid, messages) do
    receive do
      {:message, message} -> user_inbox(user_pid, messages ++ [message])
      :check_messages -> send(user_pid, messages)
                           user_inbox(user_pid, messages)
      :finish -> :ok
    end
  end
end
