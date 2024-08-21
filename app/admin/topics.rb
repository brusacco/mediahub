# frozen_string_literal: true

ActiveAdmin.register Topic do
  permit_params :name, :status, tag_ids: [], user_ids: []

  sidebar :versiones, :partial => "topics/version", only: :show
  
  controller do
    def show
      @topic = Topic.includes(versions: :item).find(params[:id])
      @versions = @topic.versions 
      @topic = @topic.versions[params[:version].to_i].reify if params[:version]
      show! #it seems to need this
    end
  end
  
  action_item :topic, only: [:show] do
    link_to "Ver historial", admin_topic_path(resource)+'/historial', method: :get
  end
  
  member_action :historial do
    @topic = Topic.find(params[:id])
    @versions = PaperTrail::Version.where(item_type: 'Topic', item_id: @topic.id)
    render "topics/historial"    
  end

  filter :name
  filter :status
  filter :users

  index do
    selectable_column
    id_column

    column 'Name' do |topic|
      link_to topic.name, admin_topic_path(topic)
    end

    column :tags

    column "Usuario(s) asignado(s)" do |topic|
      topic.users.map { |user| link_to user.name, admin_user_path(user) }.join('<br />').html_safe
    end

    column :status
    column :created_at
    actions
  end

  show do
    attributes_table do
      row :name
      row :tags
      row "Usuario(s) asignado(s)" do
        topic.users.map { |user| link_to user.name, admin_user_path(user) }.join('<br />').html_safe
      end
      row :status
      row :created_at
      row :updated_at
    end
  end

  form html: { enctype: 'multipart/form-data', multipart: true } do |f|
    columns do
      column do
        f.inputs 'Crear Tópico', multipart: true do
          f.input :name
          f.input :tags
          f.input :status
        end
      end
      column do
        f.inputs "Lista de Usuarios", multipart: :true do
          f.input :users, label:'Asiganar a:', as: :check_boxes, :collection => User.all.collect {|user| [user.name, user.id]}
        end
      end      
    end

    f.actions
  end
end
