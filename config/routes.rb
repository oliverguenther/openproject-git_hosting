OpenProject::Application.routes.draw do
  # User's own public key management
  scope '/my' do
    resources :public_keys, controller: 'my_public_keys', except: [:edit, :show, :update]
  end

  namespace 'admin' do
    resources :public_keys, controller: 'gitolite_public_keys', except: [:edit, :show, :update]
  end
end
