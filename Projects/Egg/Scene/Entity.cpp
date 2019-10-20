#include "stdafx.h"
#include "Entity.h"

using namespace Egg;
using namespace Egg::Scene;

Entity::Entity(Egg::Mesh::Multi::P mesh, Egg::Scene::RigidBody::P rigidBody)
	:mesh(mesh), rigidBody(rigidBody)
{
}

void Entity::render(const Egg::Scene::RenderParameters& params)
{
	using namespace Egg::Math;

	float4x4 perObjectMatrices[4];
	perObjectMatrices[0] = rigidBody->getModelMatrix();
	perObjectMatrices[1] = perObjectMatrices[0].invert();
	perObjectMatrices[2] =
		perObjectMatrices[0] * 
		params.camera->getViewMatrix()
		* params.camera->getProjMatrix();
	perObjectMatrices[3] = params.camera->getViewDirMatrix();
	params.context->UpdateSubresource(params.perObjectConstantBuffer.Get(), 0, nullptr, perObjectMatrices, 0, 0);

	mesh->draw(params.context, params.mien);
}


void Entity::animate(float dt, float t)
{
	rigidBody->animate(dt, t);
}