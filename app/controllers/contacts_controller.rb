class ContactsController < ApplicationController
  before_action :set_client
  before_action :set_contact, only: %i[edit update destroy]

  def new
    @contact = @client.contacts.build
    authorize @contact
  end

  def create
    @contact = @client.contacts.build(contact_params)
    authorize @contact
    if @contact.save
      redirect_to @client, notice: "Contato criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @contact.update(contact_params)
      redirect_to @client, notice: "Contato atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contact.destroy
    redirect_to @client, notice: "Contato removido."
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
