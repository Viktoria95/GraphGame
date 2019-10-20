#pragma once
#include "Mesh/Multi.h"
#include "Cam/Base.h"
#include "Scene/RigidBody.h"
#include "Scene/RenderParameters.h"

namespace Egg {
	namespace Scene
	{
		GG_CLASS(Entity)
			Egg::Mesh::Multi::P mesh;
		Egg::Scene::RigidBody::P rigidBody;

	protected:
		Entity(Egg::Mesh::Multi::P mesh, Egg::Scene::RigidBody::P rigidBody);
	public:

		void render(const Egg::Scene::RenderParameters& params);
		void animate(float dt, float t);

	GG_ENDCLASS
}}
