// #define VK_USE_PLATFORM_WIN32_KHR // Required for building on Windows, even for console Vulkan apps
#include <vulkan/vulkan.h>
#include <iostream>
#include <vector>
#include <fstream>
#include <stdexcept> // Required for std::runtime_error
#include <string>    // Added for std::string
#include <map>       // Added for std::map

// Helper function to read a SPIR-V file
static std::vector<char> readFile(const std::string& filename) {
    std::ifstream file(filename, std::ios::ate | std::ios::binary);
    if (!file.is_open()) {
        throw std::runtime_error("Failed to open file: " + filename);
    }
    size_t fileSize = (size_t)file.tellg();
    std::vector<char> buffer(fileSize);
    file.seekg(0);
    file.read(buffer.data(), fileSize);
    file.close();
    return buffer;
}

// Define your tags as in GLSL
const float TAG_ERROR_RUNTIME = 21.0f;
// ... other tags if you have them ...

std::string getErrorMessage(float tag, float value) {
    if (tag == TAG_ERROR_RUNTIME) {
        // Using static to initialize map only once
        static const std::map<float, std::string> errorMessages = {
            {10.0f, "Unhandled special form ID."},
            {11.0f, "Unhandled AST node type in main interpreter loop."},
            {12.0f, "Type error: Operator applied to non-integer arguments or mismatched types."},
            {13.0f, "Argument error: Incorrect number of arguments for operator/list processing."},
            {14.0f, "Internal error: Unknown control stack frame type."},
            {15.0f, "Execution error: Program ended with an empty operand stack."},
            // Note: 16.0f was not in your GLSL, but added for completeness if it's a possible error.
            // If it's not, you can remove it.
            {16.0f, "Execution error: Program ended due to PC reaching end with non-empty control stack."},
            {17.0f, "Execution error: Program ended with multiple values on stack (expected one result, or an error)."},
            {18.0f, "Operator error: Unknown 1-character operator."},
            {19.0f, "Operator error: Unknown multi-character operator (not 1-char and not 'mod')."},
            {20.0f, "Operator error: Invalid operator constant pool index."},
            {22.0f, "Arithmetic error: Division by zero."},
            {23.0f, "Arithmetic error: Modulo by zero."},
            {24.0f, "Internal error: Constant pool string read out of bounds."},
            {25.0f, "Stack error: Error during operand pop for operator arguments."},
            {77.0f, "Execution error: Program Counter (PC) out of bounds."},
            {80.0f, "Resource error: Operand stack overflow."},
            {81.0f, "Resource error: Operand stack underflow (pop from empty stack)."},
            {82.0f, "Resource error: Control stack overflow."},
            {90.0f, "Execution error: Program finished prematurely with an empty stack (possibly due to an earlier unreported error)."}
        };
        auto it = errorMessages.find(value);
        if (it != errorMessages.end()) {
            return "Runtime Error: " + it->second;
        }
        return "Runtime Error: Unknown error value " + std::to_string(value);
    }
    // Add other tag types if necessary (e.g., TAG_SSINT, TAG_SSBOOL etc. for non-error results)
    // For now, any non-runtime error tag will just show tag and value
    // You could expand this to print "Success: Integer" etc.
    return "Result Tag: " + std::to_string(tag) + ", Value: " + std::to_string(value);
}


int main() {
    VkApplicationInfo appInfo{};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.pApplicationName = "SExpr GLSL Host";
    appInfo.applicationVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.pEngineName = "No Engine";
    appInfo.engineVersion = VK_MAKE_VERSION(1, 0, 0);
    appInfo.apiVersion = VK_API_VERSION_1_0;

    VkInstanceCreateInfo instanceCreateInfo{};
    instanceCreateInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    instanceCreateInfo.pApplicationInfo = &appInfo;

    VkInstance instance;
    if (vkCreateInstance(&instanceCreateInfo, nullptr, &instance) != VK_SUCCESS) {
        std::cerr << "Failed to create Vulkan instance!" << std::endl;
        return EXIT_FAILURE;
    }

    uint32_t physicalDeviceCount = 0;
    vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, nullptr);
    if (physicalDeviceCount == 0) {
        std::cerr << "Failed to find GPUs with Vulkan support!" << std::endl;
        vkDestroyInstance(instance, nullptr);
        return EXIT_FAILURE;
    }
    std::vector<VkPhysicalDevice> physicalDevices(physicalDeviceCount);
    vkEnumeratePhysicalDevices(instance, &physicalDeviceCount, physicalDevices.data());
    VkPhysicalDevice physicalDevice = physicalDevices[0]; // Use the first available device

    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, nullptr);
    std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(physicalDevice, &queueFamilyCount, queueFamilies.data());

    uint32_t computeQueueFamilyIndex = -1;
    for (uint32_t i = 0; i < queueFamilyCount; ++i) {
        if (queueFamilies[i].queueFlags & VK_QUEUE_COMPUTE_BIT) {
            computeQueueFamilyIndex = i;
            break;
        }
    }
    if (computeQueueFamilyIndex == (uint32_t)-1) { // Check against -1 properly
        std::cerr << "Failed to find a queue family supporting compute operations!" << std::endl;
        vkDestroyInstance(instance, nullptr);
        return EXIT_FAILURE;
    }

    float queuePriority = 1.0f;
    VkDeviceQueueCreateInfo queueCreateInfo{};
    queueCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    queueCreateInfo.queueFamilyIndex = computeQueueFamilyIndex;
    queueCreateInfo.queueCount = 1;
    queueCreateInfo.pQueuePriorities = &queuePriority;

    VkPhysicalDeviceFeatures deviceFeatures{}; // Empty for now
    VkDeviceCreateInfo deviceCreateInfo{};
    deviceCreateInfo.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    deviceCreateInfo.pQueueCreateInfos = &queueCreateInfo;
    deviceCreateInfo.queueCreateInfoCount = 1;
    deviceCreateInfo.pEnabledFeatures = &deviceFeatures;

    VkDevice device;
    if (vkCreateDevice(physicalDevice, &deviceCreateInfo, nullptr, &device) != VK_SUCCESS) {
        std::cerr << "Failed to create logical device!" << std::endl;
        vkDestroyInstance(instance, nullptr);
        return EXIT_FAILURE;
    }

    VkQueue computeQueue;
    vkGetDeviceQueue(device, computeQueueFamilyIndex, 0, &computeQueue);

    // Create shader module
    auto shaderCode = readFile("interpreter.spv"); // SPIR-V file
    VkShaderModuleCreateInfo shaderModuleCreateInfo{};
    shaderModuleCreateInfo.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    shaderModuleCreateInfo.codeSize = shaderCode.size();
    shaderModuleCreateInfo.pCode = reinterpret_cast<const uint32_t*>(shaderCode.data());
    VkShaderModule computeShaderModule;
    if (vkCreateShaderModule(device, &shaderModuleCreateInfo, nullptr, &computeShaderModule) != VK_SUCCESS) {
        std::cerr << "Failed to create shader module!" << std::endl;
        vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }

    // Create descriptor set layout (for the output buffer)
    VkDescriptorSetLayoutBinding setLayoutBinding{};
    setLayoutBinding.binding = 0;
    setLayoutBinding.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    setLayoutBinding.descriptorCount = 1;
    setLayoutBinding.stageFlags = VK_SHADER_STAGE_COMPUTE_BIT;

    VkDescriptorSetLayoutCreateInfo setLayoutCreateInfo{};
    setLayoutCreateInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO;
    setLayoutCreateInfo.bindingCount = 1;
    setLayoutCreateInfo.pBindings = &setLayoutBinding;
    VkDescriptorSetLayout descriptorSetLayout;
    if (vkCreateDescriptorSetLayout(device, &setLayoutCreateInfo, nullptr, &descriptorSetLayout) != VK_SUCCESS) {
        std::cerr << "Failed to create descriptor set layout!" << std::endl;
        vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }

    // Create pipeline layout
    VkPipelineLayoutCreateInfo pipelineLayoutCreateInfo{};
    pipelineLayoutCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO;
    pipelineLayoutCreateInfo.setLayoutCount = 1;
    pipelineLayoutCreateInfo.pSetLayouts = &descriptorSetLayout;
    VkPipelineLayout pipelineLayout;
    if (vkCreatePipelineLayout(device, &pipelineLayoutCreateInfo, nullptr, &pipelineLayout) != VK_SUCCESS) {
        std::cerr << "Failed to create pipeline layout!" << std::endl;
        vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }

    // Create compute pipeline
    VkPipelineShaderStageCreateInfo shaderStageCreateInfo{};
    shaderStageCreateInfo.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO;
    shaderStageCreateInfo.stage = VK_SHADER_STAGE_COMPUTE_BIT;
    shaderStageCreateInfo.module = computeShaderModule;
    shaderStageCreateInfo.pName = "main"; // Entry point of the shader

    VkComputePipelineCreateInfo pipelineCreateInfo{};
    pipelineCreateInfo.sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO;
    pipelineCreateInfo.stage = shaderStageCreateInfo;
    pipelineCreateInfo.layout = pipelineLayout;
    VkPipeline computePipeline;
    if (vkCreateComputePipelines(device, VK_NULL_HANDLE, 1, &pipelineCreateInfo, nullptr, &computePipeline) != VK_SUCCESS) {
        std::cerr << "Failed to create compute pipeline!" << std::endl;
        vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }

    // Create buffer for shader output (2 floats: tag, value)
    VkDeviceSize bufferSize = sizeof(float) * 2;
    VkBuffer buffer;
    VkBufferCreateInfo bufferCreateInfoStruct{}; // Renamed to avoid conflict with variable name
    bufferCreateInfoStruct.sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO;
    bufferCreateInfoStruct.size = bufferSize;
    bufferCreateInfoStruct.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
    bufferCreateInfoStruct.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    if (vkCreateBuffer(device, &bufferCreateInfoStruct, nullptr, &buffer) != VK_SUCCESS) {
        std::cerr << "Failed to create buffer!" << std::endl;
        vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }

    VkMemoryRequirements memRequirements;
    vkGetBufferMemoryRequirements(device, buffer, &memRequirements);

    VkMemoryAllocateInfo allocInfo{};
    allocInfo.sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO;
    allocInfo.allocationSize = memRequirements.size;
    VkPhysicalDeviceMemoryProperties memProperties;
    vkGetPhysicalDeviceMemoryProperties(physicalDevice, &memProperties);
    uint32_t memoryTypeIndex = (uint32_t)-1; // Initialize properly
    for (uint32_t i = 0; i < memProperties.memoryTypeCount; i++) {
        if ((memRequirements.memoryTypeBits & (1 << i)) &&
            ((memProperties.memoryTypes[i].propertyFlags & (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) == (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT))) {
            memoryTypeIndex = i;
            break;
        }
    }
    if (memoryTypeIndex == (uint32_t)-1) {
        std::cerr << "Failed to find suitable memory type!" << std::endl;
        vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }
    allocInfo.memoryTypeIndex = memoryTypeIndex;

    VkDeviceMemory bufferMemory;
    if (vkAllocateMemory(device, &allocInfo, nullptr, &bufferMemory) != VK_SUCCESS) {
        std::cerr << "Failed to allocate buffer memory!" << std::endl;
        vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }
    vkBindBufferMemory(device, buffer, bufferMemory, 0);

    // Create descriptor pool
    VkDescriptorPoolSize poolSize{};
    poolSize.type = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    poolSize.descriptorCount = 1;
    VkDescriptorPoolCreateInfo poolCreateInfo{};
    poolCreateInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO;
    poolCreateInfo.poolSizeCount = 1;
    poolCreateInfo.pPoolSizes = &poolSize;
    poolCreateInfo.maxSets = 1;
    VkDescriptorPool descriptorPool;
    if (vkCreateDescriptorPool(device, &poolCreateInfo, nullptr, &descriptorPool) != VK_SUCCESS) {
        std::cerr << "Failed to create descriptor pool!" << std::endl;
        vkFreeMemory(device, bufferMemory, nullptr); vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }

    // Allocate descriptor set
    VkDescriptorSetAllocateInfo descSetAllocInfo{};
    descSetAllocInfo.sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO;
    descSetAllocInfo.descriptorPool = descriptorPool;
    descSetAllocInfo.descriptorSetCount = 1;
    descSetAllocInfo.pSetLayouts = &descriptorSetLayout;
    VkDescriptorSet descriptorSet;
    if (vkAllocateDescriptorSets(device, &descSetAllocInfo, &descriptorSet) != VK_SUCCESS) {
        std::cerr << "Failed to allocate descriptor set!" << std::endl;
        vkDestroyDescriptorPool(device, descriptorPool, nullptr); vkFreeMemory(device, bufferMemory, nullptr); vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr); return EXIT_FAILURE;
    }

    // Update descriptor set
    VkDescriptorBufferInfo descriptorBufferInfo{}; // Renamed to avoid conflict
    descriptorBufferInfo.buffer = buffer;
    descriptorBufferInfo.offset = 0;
    descriptorBufferInfo.range = bufferSize;
    VkWriteDescriptorSet descriptorWrite{};
    descriptorWrite.sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET;
    descriptorWrite.dstSet = descriptorSet;
    descriptorWrite.dstBinding = 0;
    descriptorWrite.dstArrayElement = 0;
    descriptorWrite.descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER;
    descriptorWrite.descriptorCount = 1;
    descriptorWrite.pBufferInfo = &descriptorBufferInfo;
    vkUpdateDescriptorSets(device, 1, &descriptorWrite, 0, nullptr);

    // Create command pool and command buffer
    VkCommandPoolCreateInfo cmdPoolCreateInfo{};
    cmdPoolCreateInfo.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    cmdPoolCreateInfo.queueFamilyIndex = computeQueueFamilyIndex;
    cmdPoolCreateInfo.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    VkCommandPool commandPool;
    if (vkCreateCommandPool(device, &cmdPoolCreateInfo, nullptr, &commandPool) != VK_SUCCESS) {
        std::cerr << "Failed to create command pool!" << std::endl;
        // ... proper cleanup ...
        vkDestroyDescriptorPool(device, descriptorPool, nullptr); vkFreeMemory(device, bufferMemory, nullptr); vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr);
        return EXIT_FAILURE;
    }

    VkCommandBufferAllocateInfo cmdBufAllocInfo{};
    cmdBufAllocInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    cmdBufAllocInfo.commandPool = commandPool;
    cmdBufAllocInfo.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    cmdBufAllocInfo.commandBufferCount = 1;
    VkCommandBuffer commandBuffer;
    if (vkAllocateCommandBuffers(device, &cmdBufAllocInfo, &commandBuffer) != VK_SUCCESS) { 
        std::cerr << "Failed to allocate command buffer!" << std::endl;
        // ... proper cleanup ...
        vkDestroyCommandPool(device, commandPool, nullptr); vkDestroyDescriptorPool(device, descriptorPool, nullptr); vkFreeMemory(device, bufferMemory, nullptr); vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr);
        return EXIT_FAILURE;
    }

    // Record command buffer
    VkCommandBufferBeginInfo beginInfo{};
    beginInfo.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO;
    vkBeginCommandBuffer(commandBuffer, &beginInfo);
    vkCmdBindPipeline(commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, computePipeline);
    vkCmdBindDescriptorSets(commandBuffer, VK_PIPELINE_BIND_POINT_COMPUTE, pipelineLayout, 0, 1, &descriptorSet, 0, nullptr);
    vkCmdDispatch(commandBuffer, 1, 1, 1); // Dispatch 1 workgroup
    vkEndCommandBuffer(commandBuffer);

    // Submit command buffer
    VkSubmitInfo submitInfo{};
    submitInfo.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO;
    submitInfo.commandBufferCount = 1;
    submitInfo.pCommandBuffers = &commandBuffer;
    VkFenceCreateInfo fenceCreateInfo{};
    fenceCreateInfo.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    VkFence fence;
    if (vkCreateFence(device, &fenceCreateInfo, nullptr, &fence) != VK_SUCCESS) { // Added error check
        std::cerr << "Failed to create fence!" << std::endl;
        // ... proper cleanup ...
        vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer); vkDestroyCommandPool(device, commandPool, nullptr); vkDestroyDescriptorPool(device, descriptorPool, nullptr); vkFreeMemory(device, bufferMemory, nullptr); vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr);
        return EXIT_FAILURE;
    }
    
    if (vkQueueSubmit(computeQueue, 1, &submitInfo, fence) != VK_SUCCESS) { // Added error check
        std::cerr << "Failed to submit queue!" << std::endl;
        // ... proper cleanup ...
        vkDestroyFence(device, fence, nullptr); vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer); vkDestroyCommandPool(device, commandPool, nullptr); vkDestroyDescriptorPool(device, descriptorPool, nullptr); vkFreeMemory(device, bufferMemory, nullptr); vkDestroyBuffer(device, buffer, nullptr); vkDestroyPipeline(device, computePipeline, nullptr); vkDestroyPipelineLayout(device, pipelineLayout, nullptr); vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr); vkDestroyShaderModule(device, computeShaderModule, nullptr); vkDestroyDevice(device, nullptr); vkDestroyInstance(instance, nullptr);
        return EXIT_FAILURE;
    }
    vkWaitForFences(device, 1, &fence, VK_TRUE, UINT64_MAX);

    // Read back results
    void* mappedMemory = nullptr;
    if (vkMapMemory(device, bufferMemory, 0, bufferSize, 0, &mappedMemory) == VK_SUCCESS) { // Added error check
        float* results = static_cast<float*>(mappedMemory);
        // std::cout << "Result Tag: " << results[0] << std::endl; // Old output
        // std::cout << "Result Value: " << results[1] << std::endl; // Old output
        std::cout << getErrorMessage(results[0], results[1]) << std::endl; // New output
        vkUnmapMemory(device, bufferMemory);
    } else {
        std::cerr << "Failed to map memory to read results!" << std::endl;
    }


    // Cleanup
    vkDestroyFence(device, fence, nullptr);
    vkFreeCommandBuffers(device, commandPool, 1, &commandBuffer); 
    vkDestroyCommandPool(device, commandPool, nullptr);
    vkDestroyDescriptorPool(device, descriptorPool, nullptr); 
    vkFreeMemory(device, bufferMemory, nullptr); 
    vkDestroyBuffer(device, buffer, nullptr);
    vkDestroyPipeline(device, computePipeline, nullptr);
    vkDestroyPipelineLayout(device, pipelineLayout, nullptr);
    vkDestroyDescriptorSetLayout(device, descriptorSetLayout, nullptr);
    vkDestroyShaderModule(device, computeShaderModule, nullptr);
    vkDestroyDevice(device, nullptr);
    vkDestroyInstance(instance, nullptr);

    return EXIT_SUCCESS;
}

