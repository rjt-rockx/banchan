defmodule BanchanWeb.ForgotPasswordLive do
  @moduledoc """
  Account Forgot Password?
  """
  use BanchanWeb, :surface_view

  alias Surface.Components.Form
  alias Surface.Components.Form.{EmailInput, ErrorTag, Field, Label, Submit}
  alias Surface.Components.Form.Input.InputContext

  alias Banchan.Accounts
  alias BanchanWeb.Components.Layout
  alias BanchanWeb.Endpoint

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(session, socket, false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <Layout current_user={@current_user} flashes={@flash}>
      <h1 class="text-2xl">Forgot your password?</h1>
      <div class="grid grid-cols-3 gap-4">
        <Form class="col-span-1" for={:user} submit="submit">
          <Field class="field" name={:email}>
            <Label class="label" />
            <div class="control has-icons-left">
              <InputContext :let={form: form, field: field}>
                <EmailInput
                  class={"input", "is-danger": !Enum.empty?(Keyword.get_values(form.errors, field))}
                  opts={required: true}
                />
              </InputContext>
              <span class="icon is-small is-left">
                <i class="fas fa-envelope" />
              </span>
            </div>
            <ErrorTag class="help is-danger" />
          </Field>
          <div class="field">
            <div class="control">
              <Submit
                class="text-center rounded-full py-1 px-5 bg-amber-200 text-black m-1"
                label="Send instructions to reset password"
              />
            </div>
          </div>
        </Form>
      </div>
    </Layout>
    """
  end

  @impl true
  def handle_event("submit", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &Routes.reset_password_url(Endpoint, :edit, &1)
      )
    end

    # Regardless of the outcome, show an impartial success/error message.
    socket =
      socket
      |> put_flash(
        :info,
        "If your email is in our system, you will receive instructions to reset your password shortly."
      )
      |> push_redirect(to: Routes.home_path(Endpoint, :index))

    {:noreply, socket}
  end
end
