Cybersourcery::Application.routes.draw do
  resources :carts, only: :new
  root to: 'carts#new'
  post 'pay', to: 'payments#pay'
  post 'confirm', to: 'payments#confirm'
  resources :responses, only: :index
end
