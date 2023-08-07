defmodule BanchanWeb.BetaLive.Requests do
  @moduledoc """
  LiveView for managing beta invites.
  """
  use BanchanWeb, :live_view

  alias Banchan.Accounts
  alias Banchan.Accounts.InviteRequest

  alias Surface.Components.Form
  alias Surface.Components.Form.{NumberInput, Submit, TextInput}

  alias BanchanWeb.Components.{Avatar, Button, InfiniteScroll, Layout, UserHandle}
  alias BanchanWeb.Components.Form.Checkbox

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = socket |> assign(show_sent: false, email_filter: "", page: 1)

    {:noreply, socket |> assign(results: list_requests(socket))}
  end

  @impl true
  def handle_event("submit_invites", %{"count" => count}, socket) do
    {count, ""} = Integer.parse(count)

    case Accounts.send_invite_batch(
           socket.assigns.current_user,
           count,
           &Routes.artist_token_url(Endpoint, :confirm_artist, &1)
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invites sent!")
         |> push_navigate(to: Routes.beta_requests_path(Endpoint, :index))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unexpected error while inviting batch: #{reason}")
         |> push_navigate(to: Routes.beta_requests_path(Endpoint, :index))}
    end
  end

  def handle_event("change_email_filter", %{"filter" => filter}, socket) do
    socket = socket |> assign(email_filter: filter, page: 1)
    {:noreply, socket |> assign(results: list_requests(socket))}
  end

  def handle_event("change_show_sent", %{"show_sent" => %{"show_sent" => show_sent}}, socket) do
    socket = socket |> assign(show_sent: show_sent == "true", page: 1)
    {:noreply, socket |> assign(results: list_requests(socket))}
  end

  @impl true
  def handle_event("send_invite", %{"value" => req_id}, socket) do
    {req_id, ""} = Integer.parse(req_id)
    %InviteRequest{} = req = Accounts.get_invite_request(req_id)

    case Accounts.send_invite(
           socket.assigns.current_user,
           req,
           &Routes.artist_token_url(Endpoint, :confirm_artist, &1)
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invite sent to #{req.email}")
         |> push_navigate(to: Routes.beta_requests_path(Endpoint, :index))}

      {:error, err} ->
        {:noreply,
         socket
         |> put_flash(:error, "Unexpected error while inviting #{req.email}: #{err}")
         |> push_navigate(to: Routes.beta_requests_path(Endpoint, :index))}
    end
  end

  def handle_event("load_more", _, socket) do
    if socket.assigns.results.total_entries >
         socket.assigns.page * socket.assigns.results.page_size do
      {:noreply, socket |> assign(page: socket.assigns.page + 1) |> fetch()}
    else
      {:noreply, socket}
    end
  end

  defp fetch(%{assigns: %{results: results, page: page}} = socket) do
    socket
    |> assign(
      :results,
      %{
        results
        | entries:
            results.entries ++
              list_requests(socket, page).entries
      }
    )
  end

  defp list_requests(socket, page \\ 1) do
    Accounts.list_invite_requests(
      unsent_only: !socket.assigns.show_sent,
      email_filter: socket.assigns.email_filter,
      page: page,
      page_size: 24
    )
  end

  @impl true
  def render(assigns) do
    ~F"""
    <Layout flashes={@flash} context={:admin}>
      <h1 class="text-3xl">Manage Invite Requests</h1>
      <div class="divider" />
      <div class="flex flex-col md:flex-row md:flex-wrap gap-2">
        <Form class="send-invites" for={%{}} as={:send_invites} submit="submit_invites">
          <div class="input-group">
            <NumberInput
              class="input input-bordered"
              name={:count}
              opts={placeholder: "Invites to send", "aria-label": "Number of invites to send"}
            />
            <Submit class="btn btn-primary rounded-lg" opts={"aria-label": "Send Invites"}>Send Invites</Submit>
          </div>
        </Form>
        <Form
          class="grow email-filter"
          for={%{}}
          as={:email_filter}
          change="change_email_filter"
          submit="change_email_filter"
          opts={role: "search"}
        >
          <div class="input-group">
            <TextInput
              class="input input-bordered"
              name={:filter}
              opts={placeholder: "Filter by email", "aria-label": "Filter by email"}
            />
            <Submit class="btn btn-primary rounded-lg" opts={"aria-label": "Filter"}>Filter</Submit>
          </div>
        </Form>
        <Form
          class="show-sent"
          for={%{}}
          as={:show_sent}
          change="change_show_sent"
          submit="change_show_sent"
          opts={role: "search"}
        >
          <Checkbox
            name={:show_sent}
            label="Show sent invites"
            value={@show_sent}
            opts={"aria-label": "Show sent invites"}
          />
        </Form>
      </div>
      <div class="divider" />
      <div class="overflow-x-auto">
        <table class="table border table-zebra border-base-content border-opacity-10 rounded w-full">
          <thead>
            <tr>
              <th />
              <th>Email</th>
              <th>Requested On</th>
              <th>Generated By</th>
              <th>Used By</th>
            </tr>
          </thead>
          <tbody>
            {#for req <- @results}
              <tr>
                <td class="action">
                  <Button class="btn-sm" click="send_invite" value={req.id}>
                    {#if is_nil(req.token_id)}
                      Send Invite
                    {#else}
                      Resend Invite
                    {/if}
                  </Button>
                </td>
                <td class="email">{req.email}</td>
                <td class="requested-on">
                  <div title={req.inserted_at |> Timex.to_datetime() |> Timex.format!("{RFC822}")}>
                    {req.inserted_at |> Timex.to_datetime() |> Timex.format!("{relative}", :relative)}
                  </div>
                </td>
                <td class="generated-by">
                  {#if req.token && req.token.generated_by}
                    <div class="flex flex-row items-center gap-2">
                      <Avatar class="w-4" user={req.token.generated_by} /> <UserHandle user={req.token.generated_by} />
                    </div>
                  {#else}
                    <span>-</span>
                  {/if}
                </td>
                <td class="used-by">
                  {#if req.token && req.token.used_by}
                    <div class="flex flex-row items-center gap-2">
                      <Avatar class="w-4" user={req.token.used_by} /> <UserHandle user={req.token.used_by} />
                    </div>
                  {#else}
                    <span>-</span>
                  {/if}
                </td>
              </tr>
            {/for}
          </tbody>
        </table>
        <InfiniteScroll id="requests-infinite-scroll" page={@page} load_more="load_more" />
      </div>
    </Layout>
    """
  end
end
