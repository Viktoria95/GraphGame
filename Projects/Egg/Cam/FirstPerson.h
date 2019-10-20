#pragma once
#include "Math/math.h"
#include "Cam/Base.h"

namespace Egg { namespace Cam {
	//TODO: shiftpressed false, gyorsul dt/t, updateproj
	GG_SUBCLASS(FirstPerson, Cam::Base)
		Egg::Math::float3 position;
		Egg::Math::float3 ahead;
		Egg::Math::float3 right;
		float yaw;
		float pitch;

		float fov;
		float aspect;
		float nearPlane;
		float farPlane;

		Egg::Math::float4x4 viewMatrix;
		Egg::Math::float4x4 projMatrix;
		Egg::Math::float4x4 viewDirMatrix;

		float speed;

		Egg::Math::int2 lastMousePos;
		Egg::Math::float2 mouseDelta;

		bool wPressed;
		bool aPressed;
		bool sPressed;
		bool dPressed;
		bool qPressed;
		bool ePressed;
		bool shiftPressed;

		void updateView();
		void updateProj();

	protected:
		FirstPerson();
	public:

		static P create(){ return P(new FirstPerson());}
		P setView(Egg::Math::float3 position, Egg::Math::float3 ahead);
		P setProj(float fov, float aspect, float nearPlane, float farPlane);
		P setSpeed(float speed);

		/// Returns eye position.
		const Egg::Math::float3& getEyePosition();
		/// Returns the ahead vector.
		const Egg::Math::float3& getAhead();
		/// Returns the ndc-to-world-view-direction matrix to be used in shaders.
		const Egg::Math::float4x4& getViewDirMatrix();
		/// Returns view matrix to be used in shaders.
		const Egg::Math::float4x4& getViewMatrix();
		/// Returns projection matrix to be used in shaders.
		const Egg::Math::float4x4& getProjMatrix();

		/// Moves camera. To be implemented if the camera has its own animation mechanism.
		virtual void animate(double dt);

		virtual void processMessage(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam);

		virtual void setAspect(float aspect);
	GG_ENDCLASS

}}