#pragma once
#include <memory>

#define GG_CLASS(T) GG_DECL(T); class T : public Egg::Shared<T>, public std::enable_shared_from_this<T> {
#define GG_SUBCLASS(T, BASE) GG_DECL(T); class T : public BASE, public Egg::Shared<T> { public: using Egg::Shared<T>::create; using Egg::Shared<T>::getShared; using Egg::Shared<T>::P; private:
#define GG_ENDCLASS };
#define GG_DECL(T) class T; using T##P = std::shared_ptr<T>; using T##W = std::weak_ptr<T>;

namespace Egg {


	template<class T> class Shared {
	public:
		template<typename... Args>
			inline static std::shared_ptr<T> create(Args&&... args)
		{	
			struct EnableMakeShared : public T {
				EnableMakeShared(Args&&...args) :T(std::forward<Args>(args)...) {}
			};
			return std::make_shared<EnableMakeShared>(std::forward<Args>(args)...);
		}
		std::shared_ptr<T> getShared() {
			return std::dynamic_pointer_cast<T>( ((T*)this)->shared_from_this());
		}

		using P = std::shared_ptr<T>;
		using W = std::weak_ptr<T>;
	};
}

