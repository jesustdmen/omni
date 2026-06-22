class ContactsController < ApplicationController
  before_action :set_client
  before_action :set_contact, only: %i[edit update destroy]

  def new
    @contact = @client.contacts.build
    authorize @contact
    @return_to = return_to_param # PB-013b
  end

  def create
    @contact = @client.contacts.build(contact_params)
    authorize @contact
    if @contact.save
      # PB-013b — contato pela aba global volta a /clients?tab=contacts; pelo cliente, ao cliente.
      redirect_to safe_return_to(fallback: @client), notice: "Contato criado."
    else
      @return_to = return_to_param
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @return_to = return_to_param
  end

  def update
    if @contact.update(contact_params)
      redirect_to safe_return_to(fallback: @client), notice: "Contato atualizado." # PB-013b
    else
      @return_to = return_to_param
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contact.destroy
    redirect_to safe_return_to(fallback: @client), notice: "Contato removido." # PB-013b
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def set_contact
    @contact = @client.contacts.find(params[:id])
    authorize @contact
  end

  def contact_params
    params.require(:contact).permit(:name, :email, :phone, :position, :is_primary)
  end
end
